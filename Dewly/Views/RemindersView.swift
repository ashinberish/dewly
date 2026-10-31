import SwiftUI
import UserNotifications

struct RemindersView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var sentTest = false

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                if status == .denied {
                    Section {
                        Button("Turn on notifications in Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    } footer: {
                        Text("Dewly can't remind you until notifications are allowed.")
                    }
                }

                Section {
                    Toggle("Reminders", isOn: $store.reminders.enabled)
                    Toggle("Smart timing", isOn: $store.reminders.smartTiming)
                        .disabled(!store.reminders.enabled)
                } footer: {
                    Text("Smart timing skips a reminder if you drank recently, and reminders stop for the day once you reach your goal.")
                }

                Section("Schedule") {
                    DatePicker("Wake", selection: timeBinding(\.wakeMinutes), displayedComponents: .hourAndMinute)
                    DatePicker("Sleep", selection: timeBinding(\.sleepMinutes), displayedComponents: .hourAndMinute)
                    Picker("Every", selection: $store.reminders.intervalMinutes) {
                        Text("60 min").tag(60)
                        Text("90 min").tag(90)
                        Text("2 hours").tag(120)
                        Text("3 hours").tag(180)
                    }
                }
                .disabled(!store.reminders.enabled)

                Section {
                    Toggle("Evening nudge", isOn: $store.reminders.eveningNudge)
                } header: {
                    Text("Streak")
                } footer: {
                    Text("At 8 PM, only if you haven't reached your goal yet.")
                }

                Section("Daily goal") {
                    Stepper(value: $store.goalML, in: 1000...5000, step: 250) {
                        LabeledContent("Goal", value: "\(store.goalML.formatted()) ml")
                    }
                }

                Section {
                    Button {
                        NotificationManager.shared.sendTest(for: store)
                        sentTest = true
                    } label: {
                        Text(sentTest ? "Sent · arrives in 3 seconds" : "Preview notification")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(status != .authorized && status != .provisional)
                }
            }
            .navigationTitle("Reminders")
            .sensoryFeedback(.selection, trigger: store.reminders)
            .task { status = await NotificationManager.shared.authorizationStatus() }
            .task(id: sentTest) {
                guard sentTest else { return }
                try? await Task.sleep(for: .seconds(3))
                sentTest = false
            }
        }
    }

    /// Bridges minutes-after-midnight storage to a DatePicker.
    private func timeBinding(_ keyPath: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding {
            let start = Calendar.current.startOfDay(for: .now)
            return Calendar.current.date(byAdding: .minute, value: store.reminders[keyPath: keyPath], to: start) ?? start
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.reminders[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

#Preview {
    RemindersView()
        .environment(HydrationStore.preview)
        .fontDesign(.rounded)
}
