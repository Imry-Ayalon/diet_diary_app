import SwiftUI
import SwiftData

@main
struct MyApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try DiaryStore.makeContainer(migratingLegacy: true)
        } catch {
            fatalError("Could not open the diary store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.layoutDirection, .rightToLeft)
        }
        .modelContainer(container)
    }
}
