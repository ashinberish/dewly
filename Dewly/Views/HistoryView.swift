import Charts
import SwiftUI

struct HistoryView: View {
    @Environment(HydrationStore.self) private var store
    @State private var range: HistoryRange = .week

    var body: some View {
        let bars = makeBars()
        let goalLitres = Double(store.goalML) / 1000
        let average = bars.isEmpty ? 0 : bars.map(\.litres).reduce(0, +) / Double(bars.count)

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Range", selection: $range.animation(.smooth)) {
                        ForEach(HistoryRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily average")
                            .font(.footnote.weight(.heavy))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(average, format: .number.precision(.fractionLength(1)))
                                .font(.system(size: 36, weight: .heavy))
                                .contentTransition(.numericText(value: average))
                            Text("L").font(.headline.weight(.heavy)).foregroundStyle(.secondary)
                        }

                        Chart {
                            ForEach(bars) { bar in
                                BarMark(
                                    x: .value("Date", bar.date, unit: range.unit),
                                    y: .value("Litres", bar.litres)
                                )
                                .foregroundStyle(bar.metGoal ? Color.accentColor : Color.accentColor.opacity(0.3))
                                .cornerRadius(range == .month ? 3 : 7)
                            }
                            RuleMark(y: .value("Goal", goalLitres))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundStyle(Color.secondary)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Goal")
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(.secondary)
                                }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: range.unit, count: range.labelStride)) { _ in
                                AxisValueLabel(format: range.labelFormat, centered: true)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 200)
                        .padding(.top, 12)
                    }
                    .padding(18)
                    .card()

                    stats
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .sensoryFeedback(.selection, trigger: range)
        }
    }

    private var stats: some View {
        let window = range.days
        let totals = store.dailyTotals
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<window).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let met = days.filter { (totals[$0] ?? 0) >= store.goalML }.count
        let total = days.reduce(0) { $0 + (totals[$1] ?? 0) }

        return VStack(spacing: 0) {
            statRow("Goals met", "\(met) of \(window)")
            Divider().padding(.horizontal, 16)
            statRow("Total", "\((Double(total) / 1000).formatted(.number.precision(.fractionLength(1)))) L")
            Divider().padding(.horizontal, 16)
            statRow("Best streak", "\(store.bestStreak) days")
        }
        .card()
    }

    private func statRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title).font(.body.weight(.bold))
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    /// Week and month show each day; year shows the daily average for each month.
    private func makeBars() -> [HistoryBar] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let totals = store.dailyTotals
        let goal = store.goalML

        switch range {
        case .week, .month:
            return (0..<range.days).reversed().compactMap { offset -> HistoryBar? in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                let ml = totals[day] ?? 0
                return HistoryBar(date: day, litres: Double(ml) / 1000, metGoal: ml >= goal)
            }
        case .year:
            guard let thisMonth = calendar.dateInterval(of: .month, for: today)?.start,
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
            return (0..<12).reversed().compactMap { offset -> HistoryBar? in
                guard let month = calendar.date(byAdding: .month, value: -offset, to: thisMonth),
                      let interval = calendar.dateInterval(of: .month, for: month) else { return nil }
                let end = min(interval.end, tomorrow)
                let dayCount = max(1, calendar.dateComponents([.day], from: interval.start, to: end).day ?? 1)
                let sum = totals.filter { $0.key >= interval.start && $0.key < end }.values.reduce(0, +)
                let average = Double(sum) / Double(dayCount)
                return HistoryBar(date: month, litres: average / 1000, metGoal: average >= Double(goal))
            }
        }
    }
}

struct HistoryBar: Identifiable {
    var date: Date
    var litres: Double
    var metGoal: Bool
    var id: Date { date }
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case week, month, year

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .year: 365
        }
    }

    var unit: Calendar.Component {
        self == .year ? .month : .day
    }

    var labelStride: Int {
        self == .month ? 7 : 1
    }

    var labelFormat: Date.FormatStyle {
        switch self {
        case .week: .dateTime.weekday(.narrow)
        case .month: .dateTime.day()
        case .year: .dateTime.month(.narrow)
        }
    }
}

#Preview {
    HistoryView()
        .environment(HydrationStore.preview)
        .fontDesign(.rounded)
}
