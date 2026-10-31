import SwiftUI

struct TodayView: View {
    @Environment(HydrationStore.self) private var store
    @State private var showingAddSheet = false
    @State private var lastAdded: DrinkEntry?
    @State private var toastTask: Task<Void, Never>?

    private let quickAmounts = [150, 250, 500]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)

                    ring
                    quickAdd
                    nextReminder
                    logSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    StreakBadge(count: store.currentStreak)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddWaterSheet { ml in log(ml) }
                    .presentationDetents([.medium])
                    .presentationCornerRadius(40)
                    .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottom) {
                if let lastAdded {
                    UndoToast(entry: lastAdded) { undo(lastAdded) }
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                }
            }
            .sensoryFeedback(.increase, trigger: store.todayTotal) { old, new in new > old }
            .sensoryFeedback(.success, trigger: store.goalMetToday) { old, new in !old && new }
        }
    }

    // MARK: - Sections

    private var ring: some View {
        VStack(spacing: 10) {
            ProgressRing(progress: store.progressToday)
                .frame(width: 236, height: 236)
                .overlay {
                    VStack(spacing: 2) {
                        Text(store.todayTotal, format: .number)
                            .font(.system(size: 50, weight: .heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(store.todayTotal)))
                        Text("of \(store.goalML.formatted()) ml")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(store.todayTotal) of \(store.goalML) millilitres")

            Group {
                if store.goalMetToday {
                    Label("Goal reached · streak extended", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(store.remainingToday.formatted()) ml to go")
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(store.remainingToday)))
                }
            }
            .font(.subheadline.weight(.bold))
        }
        .padding(.top, 4)
    }

    private var quickAdd: some View {
        HStack(spacing: 8) {
            ForEach(quickAmounts, id: \.self) { ml in
                Button("+\(ml)") { log(ml) }
                    .buttonStyle(PillButtonStyle())
                    .accessibilityLabel("Add \(ml) millilitres")
            }
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
            }
            .buttonStyle(PillButtonStyle(prominent: true))
            .frame(width: 52)
            .accessibilityLabel("Custom amount")
        }
    }

    private var nextReminder: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text("Next reminder")
                .font(.body.weight(.bold))
            Spacer()
            Text(nextReminderText)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .card()
    }

    private var logSection: some View {
        VStack(spacing: 8) {
            let entries = store.todayEntries
            SectionHeader(title: "Log", detail: entries.count == 1 ? "1 drink" : "\(entries.count) drinks")
            VStack(spacing: 0) {
                if entries.isEmpty {
                    Text("Nothing logged yet today.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                } else {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.name).font(.body.weight(.bold))
                            Spacer()
                            Text("\(entry.ml) ml · \(entry.date.formatted(date: .omitted, time: .shortened))")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        if entry.id != entries.last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
            }
            .card()
        }
    }

    // MARK: - Actions

    private var nextReminderText: String {
        if store.goalMetToday { return "Tomorrow" }
        if !store.reminders.enabled { return "Off" }
        let settings = store.reminders
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        var minute = settings.wakeMinutes + settings.intervalMinutes
        while minute <= settings.sleepMinutes {
            if let date = calendar.date(byAdding: .minute, value: minute, to: start), date > .now {
                return date.formatted(date: .omitted, time: .shortened)
            }
            minute += max(settings.intervalMinutes, 15)
        }
        return "Tomorrow"
    }

    private func log(_ ml: Int) {
        var entry: DrinkEntry?
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            entry = store.add(ml)
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            lastAdded = entry
        }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { lastAdded = nil }
        }
    }

    private func undo(_ entry: DrinkEntry) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 1)) {
            store.remove(entry)
            lastAdded = nil
        }
    }
}

#Preview {
    TodayView()
        .environment(HydrationStore.preview)
        .fontDesign(.rounded)
}
