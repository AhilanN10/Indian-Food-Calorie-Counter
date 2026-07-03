import SwiftUI
import SwiftData

@main
struct IndianFoodApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MealLog.self)
    }
}
