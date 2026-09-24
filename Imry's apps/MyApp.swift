import SwiftUI
import SwiftData

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.layoutDirection, .rightToLeft)
        }
        .modelContainer(for: FoodEntry.self)
    }
}
