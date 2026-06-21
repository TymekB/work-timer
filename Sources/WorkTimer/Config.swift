import Foundation

enum Config {
    private static let defaults = UserDefaults.standard

    private enum Keys {
        static let idleThreshold = "worktimer.config.idleThreshold"
        static let claudeEnabled = "worktimer.config.claudeEnabled"
        static let cpuThreshold = "worktimer.config.cpuThreshold"
        static let resetHours = "worktimer.config.resetHours"
    }

    static var resetHours: [Int] {
        get { (defaults.object(forKey: Keys.resetHours) as? [Int]) ?? [6, 17] }
        set { defaults.set(newValue, forKey: Keys.resetHours) }
    }

    static var idleThreshold: Double {
        get { defaults.object(forKey: Keys.idleThreshold) as? Double ?? 120 }
        set { defaults.set(newValue, forKey: Keys.idleThreshold) }
    }

    static var claudeDetectionEnabled: Bool {
        get { defaults.object(forKey: Keys.claudeEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.claudeEnabled) }
    }

    static var claudeCpuThreshold: Double {
        get { defaults.object(forKey: Keys.cpuThreshold) as? Double ?? 10 }
        set { defaults.set(newValue, forKey: Keys.cpuThreshold) }
    }
}
