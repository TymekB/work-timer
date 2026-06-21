import Foundation

enum CountingState {
    case user
    case claude
    case away
    case paused
}

final class TimeTracker {
    var idleThreshold: Double
    var claudeDetectionEnabled: Bool
    var resetHours: [Int]
    var isPaused = false

    private(set) var seconds: Double = 0
    private(set) var state: CountingState = .away

    private var pendingGrace: Double = 0
    private let realInputEpsilon: Double = 2

    private var currentDay: String
    private let defaults = UserDefaults.standard

    init(idleThreshold: Double, claudeDetectionEnabled: Bool, resetHours: [Int]) {
        self.idleThreshold = idleThreshold
        self.claudeDetectionEnabled = claudeDetectionEnabled
        self.resetHours = resetHours
        self.currentDay = Self.periodKey(for: Date(), resetHours: resetHours)
        self.seconds = defaults.double(forKey: storageKey(for: currentDay))
    }

    func tick(delta: Double, idleSeconds: Double, claudeWorking: Bool) {
        rolloverIfNeeded()

        if isPaused {
            state = .paused
            return
        }

        let realInput = idleSeconds < realInputEpsilon
        if realInput {
            pendingGrace = 0
        }

        let userActive = idleSeconds < idleThreshold
        let claudeCovered = claudeDetectionEnabled && claudeWorking
        if userActive {
            state = .user
        } else if claudeCovered {
            state = .claude
        } else {
            state = .away
        }

        if state == .user || state == .claude {
            seconds += delta
            if state == .user && !claudeCovered && !realInput {
                pendingGrace += delta
            }
            persist()
        }

        if state == .away && pendingGrace > 0 {
            seconds = max(0, seconds - pendingGrace)
            pendingGrace = 0
            persist()
        }
    }

    func reset() {
        seconds = 0
        persist()
    }

    private func persist() {
        defaults.set(seconds, forKey: storageKey(for: currentDay))
    }

    private func rolloverIfNeeded() {
        let today = Self.periodKey(for: Date(), resetHours: resetHours)
        guard today != currentDay else { return }
        currentDay = today
        seconds = defaults.double(forKey: storageKey(for: today))
    }

    private func storageKey(for day: String) -> String {
        "worktimer.seconds.\(day)"
    }

    private static func periodKey(for date: Date, resetHours: [Int]) -> String {
        let calendar = Calendar.current
        let sortedHours = resetHours.sorted()
        let startOfDay = calendar.startOfDay(for: date)

        var boundary: Date?
        for hour in sortedHours {
            if let candidate = calendar.date(byAdding: .hour, value: hour, to: startOfDay), candidate <= date {
                boundary = candidate
            }
        }
        if boundary == nil, let lastHour = sortedHours.last,
           let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) {
            boundary = calendar.date(byAdding: .hour, value: lastHour, to: startOfYesterday)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: boundary ?? date)
    }
}
