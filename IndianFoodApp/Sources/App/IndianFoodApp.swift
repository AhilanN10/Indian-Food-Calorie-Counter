import SwiftUI
import SwiftData

@main
struct IndianFoodApp: App {
    @StateObject private var profileStore = ProfileStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
        }
        .modelContainer(for: MealLog.self)
    }
}
