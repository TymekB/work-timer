import Foundation

struct DayStat {
    let date: Date
    let seconds: Double
}

enum Statistics {
    private static let prefix = "worktimer.seconds."

    private static var workCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.locale = Locale.current
        calendar.timeZone = TimeZone.current
        return calendar
    }

    private static func allPeriods() -> [(date: Date, seconds: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var result: [(date: Date, seconds: Double)] = []
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            guard key.hasPrefix(prefix), let seconds = value as? Double else { continue }
            let raw = String(key.dropFirst(prefix.count))
            guard let date = formatter.date(from: raw) else { continue }
            result.append((date, seconds))
        }
        return result
    }

    static func currentWeekTotal(now: Date = Date()) -> Double {
        currentWeekByDay(now: now).reduce(0) { $0 + $1.seconds }
    }

    static func currentWeekByDay(now: Date = Date()) -> [DayStat] {
        let calendar = workCalendar
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let periods = allPeriods()

        var days: [DayStat] = []
        for offset in 0..<5 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { continue }
            let total = periods
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.seconds }
            days.append(DayStat(date: day, seconds: total))
        }
        return days
    }
}
