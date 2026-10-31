import SwiftUI

@main
struct DewlyApp: App {
    @State private var store = HydrationStore.shared

    init() {
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .fontDesign(.rounded)
        }
    }
}
