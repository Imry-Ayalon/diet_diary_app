import SwiftUI
import SwiftData

@main
struct RideApp: App {
    private let rides: ModelContainer
    private let diary: ModelContainer

    init() {
        do {
            rides = try RideLibrary.makeContainer()
            diary = try DiaryStore.makeContainer(migratingLegacy: false)
        } catch {
            fatalError("Could not open the ride stores: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RideHomeView(diary: diary)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .modelContainer(rides)
    }
}
