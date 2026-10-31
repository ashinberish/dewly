import Foundation
import Observation

struct DrinkEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var ml: Int
    var date: Date
}

struct ReminderSettings: Codable, Equatable {
    var enabled = true
    /// Skips a reminder if you drank recently.
    var smartTiming = true
    /// Minutes after midnight.
    var wakeMinutes = 7 * 60
    var sleepMinutes = 22 * 60 + 30
    var intervalMinutes = 90
    /// One extra reminder at 20:00 if today's goal isn't met yet.
    var eveningNudge = true
}

/// Single source of truth for intake, goal, streaks and reminder settings.
/// Persists to UserDefaults as one JSON snapshot.
@MainActor
@Observable
final class HydrationStore {
    static let shared = HydrationStore()

    var goalML: Int { didSet { save(); NotificationManager.shared.reschedule(for: self) } }
    private(set) var entries: [DrinkEntry] { didSet { save() } }
    var reminders: ReminderSettings { didSet { save(); NotificationManager.shared.reschedule(for: self) } }
    var hasOnboarded: Bool { didSet { save() } }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar = Calendar.current
    private static let storageKey = "dewly.state.v1"

    private struct Snapshot: Codable {
        var goalML: Int
        var entries: [DrinkEntry]
        var reminders: ReminderSettings
        var hasOnboarded: Bool
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            goalML = snapshot.goalML
            entries = snapshot.entries
            reminders = snapshot.reminders
            hasOnboarded = snapshot.hasOnboarded
        } else {
            goalML = 2500
            entries = []
            reminders = ReminderSettings()
            hasOnboarded = false
        }
    }

    private func save() {
        let snapshot = Snapshot(goalML: goalML, entries: entries, reminders: reminders, hasOnboarded: hasOnboarded)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Mutations

    @discardableResult
    func add(_ ml: Int, at date: Date = .now) -> DrinkEntry {
        let entry = DrinkEntry(ml: ml, date: date)
        entries.append(entry)
        NotificationManager.shared.reschedule(for: self)
        return entry
    }

    func remove(_ entry: DrinkEntry) {
        entries.removeAll { $0.id == entry.id }
        NotificationManager.shared.reschedule(for: self)
    }

    // MARK: - Today

    var todayEntries: [DrinkEntry] {
        entries.filter { calendar.isDateInToday($0.date) }.sorted { $0.date > $1.date }
    }

    var todayTotal: Int { total(on: .now) }
    var remainingToday: Int { max(goalML - todayTotal, 0) }
    var goalMetToday: Bool { todayTotal >= goalML }
    var progressToday: Double { goalML > 0 ? Double(todayTotal) / Double(goalML) : 0 }

    // MARK: - History & streaks

    /// Total ml per day, keyed by start of day.
    var dailyTotals: [Date: Int] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.ml } }
    }

    func total(on day: Date) -> Int {
        entries.reduce(0) { calendar.isDate($1.date, inSameDayAs: day) ? $0 + $1.ml : $0 }
    }

    func goalMet(on day: Date) -> Bool { total(on: day) >= goalML }

    /// Consecutive days at or above goal. Today counts once met; until then
    /// the streak is still alive from yesterday.
    var currentStreak: Int {
        let totals = dailyTotals
        var day = calendar.startOfDay(for: .now)
        if (totals[day] ?? 0) < goalML {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while (totals[day] ?? 0) >= goalML {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var bestStreak: Int {
        let metDays = dailyTotals.filter { $0.value >= goalML }.keys.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in metDays {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

// MARK: - Previews

extension HydrationStore {
    /// In-memory store with three weeks of sample data, for SwiftUI previews.
    static var preview: HydrationStore {
        let defaults = UserDefaults(suiteName: "dewly.preview")!
        defaults.removePersistentDomain(forName: "dewly.preview")
        let store = HydrationStore(defaults: defaults)
        store.hasOnboarded = true
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for offset in 1...24 where offset != 13 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            for (hour, ml) in [(8, 500), (11, 250), (13, 500), (16, 500), (18, 500), (20, 400)] {
                store.entries.append(DrinkEntry(ml: ml, date: day.addingTimeInterval(Double(hour) * 3600)))
            }
        }
        store.entries.append(DrinkEntry(ml: 500, date: today.addingTimeInterval(8 * 3600)))
        store.entries.append(DrinkEntry(ml: 250, date: today.addingTimeInterval(9.3 * 3600)))
        return store
    }
}
