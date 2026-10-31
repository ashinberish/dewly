import SwiftUI

struct RootView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Today", systemImage: "circle.bottomhalf.filled") {
                TodayView()
            }
            Tab("Streak", systemImage: "flame") {
                StreakView()
            }
            Tab("History", systemImage: "chart.bar") {
                HistoryView()
            }
            Tab("Reminders", systemImage: "bell") {
                RemindersView()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !store.hasOnboarded }, set: { _ in })) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Day may have rolled over, or a notification action may have logged water.
            if phase == .active {
                NotificationManager.shared.reschedule(for: store)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(HydrationStore.preview)
        .fontDesign(.rounded)
}
