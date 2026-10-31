import Foundation
import UserNotifications

/// Schedules drink reminders as one-shot local notifications for the next few days.
/// Rescheduled whenever intake or settings change, so reminders stop once the goal
/// is met and (with smart timing) skip slots right after you drank.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    enum ID {
        static let category = "DRINK_REMINDER"
        static let log250 = "LOG_250"
        static let log500 = "LOG_500"
        static let snooze = "SNOOZE_30"
    }

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    /// iOS keeps at most 64 pending requests per app.
    private let maxPending = 60

    private override init() {
        super.init()
    }

    func configure() {
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: ID.log250, title: "Log 250 ml", options: []),
            UNNotificationAction(identifier: ID.log500, title: "Log 500 ml", options: []),
            UNNotificationAction(identifier: ID.snooze, title: "Remind me in 30 min", options: []),
        ]
        let category = UNNotificationCategory(identifier: ID.category, actions: actions, intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    func reschedule(for store: HydrationStore) {
        center.removeAllPendingNotificationRequests()
        let settings = store.reminders
        guard settings.enabled, store.hasOnboarded else { return }

        let now = Date.now
        let lastDrink = store.entries.map(\.date).max()
        let quietWindow = TimeInterval(settings.intervalMinutes * 60) / 2
        var scheduled = 0

        for dayOffset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let isToday = dayOffset == 0
            if isToday && store.goalMetToday { continue }

            for slot in slots(on: day, settings: settings) where slot > now {
                if isToday, settings.smartTiming, let lastDrink, slot.timeIntervalSince(lastDrink) < quietWindow {
                    continue
                }
                let body = isToday
                    ? "\(store.remainingToday.formatted()) ml to go today."
                    : "Time for a glass of water."
                schedule(id: "reminder-\(Int(slot.timeIntervalSince1970))", title: "Time for a glass", body: body, at: slot)
                scheduled += 1
                if scheduled >= maxPending { return }
            }
        }

        if settings.eveningNudge, !store.goalMetToday,
           let nudge = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now), nudge > now {
            let streak = store.currentStreak
            let body = streak > 0
                ? "\(store.remainingToday.formatted()) ml to go to keep your \(streak)-day streak."
                : "\(store.remainingToday.formatted()) ml to go to reach today's goal."
            schedule(id: "evening-nudge", title: "Don't break the chain", body: body, at: nudge)
        }
    }

    func sendTest(for store: HydrationStore) {
        let body = store.goalMetToday
            ? "Goal reached. \(store.currentStreak) days and counting."
            : "\(store.remainingToday.formatted()) ml to go today."
        let content = makeContent(title: "Time for a glass", body: body)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        center.add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger), withCompletionHandler: nil)
    }

    private func snooze() {
        let content = makeContent(title: "Time for a glass", body: "Here's the reminder you asked for.")
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        center.add(UNNotificationRequest(identifier: "snooze", content: content, trigger: trigger), withCompletionHandler: nil)
    }

    private func slots(on day: Date, settings: ReminderSettings) -> [Date] {
        let start = calendar.startOfDay(for: day)
        var result: [Date] = []
        var minute = settings.wakeMinutes + settings.intervalMinutes
        while minute <= settings.sleepMinutes {
            if let date = calendar.date(byAdding: .minute, value: minute, to: start) {
                result.append(date)
            }
            minute += max(settings.intervalMinutes, 15)
        }
        return result
    }

    private func schedule(id: String, title: String, body: String, at date: Date) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: makeContent(title: title, body: body), trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    private func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = ID.category
        return content
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        await MainActor.run {
            let store = HydrationStore.shared
            switch action {
            case ID.log250: store.add(250)
            case ID.log500: store.add(500)
            case ID.snooze: self.snooze()
            default: break
            }
        }
    }
}
