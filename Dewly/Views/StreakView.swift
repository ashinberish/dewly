import SwiftUI

struct StreakView: View {
    @Environment(HydrationStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    hero
                    WeekStrip()
                    MonthGrid(month: .now)
                    milestones
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Streak")
        }
    }

    private var hero: some View {
        let streak = store.currentStreak
        let best = max(store.bestStreak, streak)
        return HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
                .frame(width: 68, height: 68)
                .background(Color.orange.opacity(0.15), in: Circle())
                .symbolEffect(.bounce, value: streak)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(streak, format: .number)
                        .font(.system(size: 60, weight: .heavy))
                        .contentTransition(.numericText(value: Double(streak)))
                    Text(streak == 1 ? "day" : "days")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.secondary)
                }
                Text(best > streak ? "Best \(best) days · \(best - streak) to go" : "Your best streak yet")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .card()
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    private var milestones: some View {
        let best = max(store.bestStreak, store.currentStreak)
        return VStack(spacing: 8) {
            SectionHeader(title: "Milestones")
            HStack(spacing: 8) {
                ForEach([7, 30, 100], id: \.self) { target in
                    let earned = best >= target
                    VStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.15), in: Circle())
                        Text("\(target) days")
                            .font(.subheadline.weight(.heavy))
                        Text(earned ? "Earned" : "\(target - store.currentStreak) to go")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .card()
                    .opacity(earned ? 1 : 0.45)
                }
            }
        }
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    @Environment(HydrationStore.self) private var store

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }

        HStack {
            ForEach(days, id: \.self) { day in
                let met = store.goalMet(on: day)
                let isToday = calendar.isDateInToday(day)
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(met ? Color.accentColor : Color(.tertiarySystemFill))
                        if met {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.black))
                                .foregroundStyle(.white)
                        } else if isToday {
                            Circle()
                                .fill(Color(.secondarySystemGroupedBackground))
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        }
                    }
                    .frame(width: 32, height: 32)
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .card()
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.goalMetToday)
    }
}

// MARK: - Month grid

struct MonthGrid: View {
    @Environment(HydrationStore.self) private var store
    var month: Date

    private enum Cell: Hashable {
        case weekday(Int, String)
        case pad(Int)
        case day(Date)
    }

    var body: some View {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: month)
        let start = interval?.start ?? month
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let ordered = (0..<7).map { symbols[($0 + calendar.firstWeekday - 1) % 7] }

        let headerCells: [Cell] = ordered.enumerated().map { Cell.weekday($0.offset, $0.element) }
        let padCells: [Cell] = (0..<leading).map { Cell.pad($0) }
        let dayCells: [Cell] = days.map { Cell.day($0) }
        let cells = headerCells + padCells + dayCells
        let metCount = days.filter { store.goalMet(on: $0) }.count
        let elapsed = days.filter { $0 <= .now }.count

        VStack(spacing: 8) {
            SectionHeader(title: "\(month.formatted(.dateTime.month(.wide)))", detail: "\(metCount) of \(elapsed)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(cells, id: \.self) { cell in
                    switch cell {
                    case .weekday(_, let symbol):
                        Text(symbol)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.tertiary)
                    case .pad:
                        Color.clear.frame(height: 34)
                    case .day(let date):
                        dayCell(date, calendar: calendar)
                    }
                }
            }
            .padding(12)
            .card()
        }
    }

    private func dayCell(_ date: Date, calendar: Calendar) -> some View {
        let met = store.goalMet(on: date)
        let isToday = calendar.isDateInToday(date)
        let future = date > .now
        let color: Color = met ? .white : isToday ? .accentColor : future ? Color(.tertiaryLabel) : Color(.secondaryLabel)

        return Text(calendar.component(.day, from: date), format: .number)
            .font(.footnote.weight(isToday ? .heavy : .bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(met ? Color.accentColor : Color.clear, in: Circle())
            .overlay {
                if isToday && !met {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
    }
}

#Preview {
    StreakView()
        .environment(HydrationStore.preview)
        .fontDesign(.rounded)
}
