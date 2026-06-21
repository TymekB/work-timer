import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statsMenu: NSMenu!
    private var timer: Timer?

    private let tracker = TimeTracker(
        idleThreshold: Config.idleThreshold,
        claudeDetectionEnabled: Config.claudeDetectionEnabled,
        resetHours: Config.resetHours
    )
    private let claudeMonitor = ClaudeMonitor(cpuThreshold: Config.claudeCpuThreshold)

    private var lastTick = Date()
    private var lastClaudeCheck = Date(timeIntervalSince1970: 0)
    private var claudeWorking = false

    private let tickInterval: TimeInterval = 1
    private let claudeCheckInterval: TimeInterval = 2
    private let maxDelta: TimeInterval = 3

    private var statusInfoItem: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private var claudeToggleItem: NSMenuItem!
    private var claudeInfoItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        render()

        let timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.onTick()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func onTick() {
        let now = Date()
        let delta = min(now.timeIntervalSince(lastTick), maxDelta)
        lastTick = now

        if now.timeIntervalSince(lastClaudeCheck) >= claudeCheckInterval {
            claudeWorking = claudeMonitor.isWorking()
            lastClaudeCheck = now
        }

        let idle = IdleMonitor.secondsSinceLastInput()
        tracker.tick(delta: delta, idleSeconds: idle, claudeWorking: claudeWorking)
        render()
    }

    private func render() {
        guard let button = statusItem.button else { return }

        let symbol: String
        switch tracker.state {
        case .user: symbol = "🟢"
        case .claude: symbol = "🤖"
        case .away: symbol = "🟡"
        case .paused: symbol = "⏸"
        }

        let attributed = NSMutableAttributedString(string: "\(symbol) ")
        attributed.append(NSAttributedString(
            string: format(tracker.seconds),
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)]
        ))
        button.attributedTitle = attributed

        statusInfoItem.title = statusDescription()
        pauseItem.title = tracker.isPaused ? "Wznów" : "Wstrzymaj"
        claudeToggleItem.state = tracker.claudeDetectionEnabled ? .on : .off
        claudeInfoItem.title = claudeDescription()
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
    }

    private func statusDescription() -> String {
        switch tracker.state {
        case .user: return "Liczę — jesteś aktywny"
        case .claude: return "Liczę — Claude pracuje"
        case .away: return "Wstrzymane — brak aktywności"
        case .paused: return "Wstrzymane ręcznie"
        }
    }

    private func claudeDescription() -> String {
        if !tracker.claudeDetectionEnabled {
            return "Claude: wykrywanie wyłączone"
        }
        let cpu = String(format: "%.0f%%", claudeMonitor.lastCpu)
        if !claudeMonitor.lastRunning {
            return "Claude: nieuruchomiony"
        }
        return claudeWorking ? "Claude: pracuje (\(cpu) CPU)" : "Claude: bezczynny (\(cpu) CPU)"
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        statusInfoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusInfoItem.isEnabled = false
        menu.addItem(statusInfoItem)

        claudeInfoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        claudeInfoItem.isEnabled = false
        menu.addItem(claudeInfoItem)

        menu.addItem(.separator())

        statsMenu = NSMenu()
        statsMenu.delegate = self
        statsMenu.autoenablesItems = false
        let statsParent = NSMenuItem(title: "Statystyki tygodnia", action: nil, keyEquivalent: "")
        statsParent.submenu = statsMenu
        menu.addItem(statsParent)

        menu.addItem(.separator())

        pauseItem = NSMenuItem(title: "Wstrzymaj", action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let resetItem = NSMenuItem(title: "Resetuj licznik", action: #selector(resetCounter), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        claudeToggleItem = NSMenuItem(title: "Licz, gdy Claude pracuje", action: #selector(toggleClaude), keyEquivalent: "")
        claudeToggleItem.target = self
        menu.addItem(claudeToggleItem)

        let idleMenu = NSMenu()
        for minutes in [1, 2, 5, 10] {
            let item = NSMenuItem(title: "\(minutes) min", action: #selector(setIdleThreshold(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            idleMenu.addItem(item)
        }
        let idleParent = NSMenuItem(title: "Próg bezczynności", action: nil, keyEquivalent: "")
        idleParent.submenu = idleMenu
        menu.addItem(idleParent)
        syncIdleMenu(idleMenu)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(title: "Uruchamiaj przy starcie", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        let quitItem = NSMenuItem(title: "Zakończ", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func syncIdleMenu(_ menu: NSMenu) {
        let current = Int(tracker.idleThreshold / 60)
        for item in menu.items {
            item.state = item.tag == current ? .on : .off
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == statsMenu else { return }
        rebuildStatsMenu()
    }

    private func rebuildStatsMenu() {
        statsMenu.removeAllItems()

        let now = Date()
        let total = Statistics.currentWeekTotal(now: now)
        let totalItem = NSMenuItem(title: "Razem (pon–pt): \(format(total))", action: nil, keyEquivalent: "")
        totalItem.isEnabled = false
        statsMenu.addItem(totalItem)

        statsMenu.addItem(.separator())

        let labelFormatter = DateFormatter()
        labelFormatter.locale = Locale(identifier: "pl_PL")
        labelFormatter.dateFormat = "EEE dd.MM"

        let calendar = Calendar.current
        for day in Statistics.currentWeekByDay(now: now) {
            let isToday = calendar.isDate(day.date, inSameDayAs: now)
            let label = labelFormatter.string(from: day.date)
            let title = "\(label):  \(format(day.seconds))"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            if isToday {
                item.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
                )
            }
            statsMenu.addItem(item)
        }
    }

    @objc private func togglePause() {
        tracker.isPaused.toggle()
        render()
    }

    @objc private func resetCounter() {
        tracker.reset()
        render()
    }

    @objc private func toggleClaude() {
        tracker.claudeDetectionEnabled.toggle()
        Config.claudeDetectionEnabled = tracker.claudeDetectionEnabled
        render()
    }

    @objc private func setIdleThreshold(_ sender: NSMenuItem) {
        let seconds = Double(sender.tag * 60)
        tracker.idleThreshold = seconds
        Config.idleThreshold = seconds
        if let menu = sender.menu {
            syncIdleMenu(menu)
        }
        render()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled() {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("WorkTimer: launch-at-login change failed: \(error)")
        }
        render()
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
