import AppKit
import SwiftUI

final class StatsWindowController: NSWindowController, NSWindowDelegate {
    private let model = StatsModel()
    private var refreshTimer: Timer?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Statistics — WorkTimer"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
        model.refresh()
        window.contentViewController = NSHostingController(rootView: StatsView(model: model))
    }

    func show() {
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startTimer()
    }

    private func startTimer() {
        refreshTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.model.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
