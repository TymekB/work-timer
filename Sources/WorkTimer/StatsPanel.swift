import SwiftUI
import Charts

struct DayBar: Identifiable {
    let id: String
    let label: String
    let hours: Double
    let valueText: String
    let isToday: Bool
}

final class StatsModel: ObservableObject {
    @Published var bars: [DayBar] = []
    @Published var totalText: String = "0:00:00"
    @Published var rangeText: String = ""
    @Published var weekOffset: Int = 0

    func refresh() {
        let calendar = Calendar.current
        let now = Date()
        let reference = calendar.date(byAdding: .day, value: weekOffset * 7, to: now) ?? now
        let days = Statistics.currentWeekByDay(now: reference)
        let total = days.reduce(0) { $0 + $1.seconds }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "pl_PL")
        weekdayFormatter.dateFormat = "EEE"

        bars = days.map { day in
            DayBar(
                id: ISO8601DateFormatter().string(from: day.date),
                label: weekdayFormatter.string(from: day.date),
                hours: day.seconds / 3600,
                valueText: Self.shortText(day.seconds),
                isToday: weekOffset == 0 && calendar.isDate(day.date, inSameDayAs: now)
            )
        }
        totalText = Self.fullText(total)

        let rangeFormatter = DateFormatter()
        rangeFormatter.locale = Locale(identifier: "pl_PL")
        rangeFormatter.dateFormat = "dd.MM"
        if let first = days.first?.date, let last = days.last?.date {
            rangeText = "\(rangeFormatter.string(from: first)) – \(rangeFormatter.string(from: last))"
        }
    }

    func shift(_ delta: Int) {
        weekOffset = min(0, weekOffset + delta)
        refresh()
    }

    static func fullText(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func shortText(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

struct StatsView: View {
    @ObservedObject var model: StatsModel

    private var maxHours: Double {
        max(model.bars.map(\.hours).max() ?? 0, 1)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { model.shift(-1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(model.weekOffset == 0 ? "Ten tydzień" : "Tydzień")
                        .font(.headline)
                    Text(model.rangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { model.shift(1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(model.weekOffset >= 0)
            }

            Text("Razem: \(model.totalText)")
                .font(.title2.bold())

            Chart(model.bars) { bar in
                BarMark(
                    x: .value("Dzień", bar.label),
                    y: .value("Godziny", bar.hours)
                )
                .foregroundStyle(bar.isToday ? Color.green : Color.accentColor)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(bar.valueText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: 0...(maxHours * 1.2))
            .chartYAxisLabel("godziny")
            .frame(minHeight: 240)
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 360)
    }
}
