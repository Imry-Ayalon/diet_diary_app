import SwiftUI
import SwiftData

@main
struct RideApp: App {
    private let rides: ModelContainer
    private let diary: ModelContainer

    @AppStorage("movementLanguage") private var languageRaw = MovementLanguage.hebrew.rawValue

    init() {
        do {
            rides = try RideLibrary.makeContainer()
            diary = try DiaryStore.makeContainer(migratingLegacy: false)
        } catch {
            fatalError("Could not open the ride stores: \(error)")
        }
    }

    private var language: MovementLanguage {
        MovementLanguage(rawValue: languageRaw) ?? .hebrew
    }

    var body: some Scene {
        WindowGroup {
            RideHomeView(diary: diary)
                .environment(\.layoutDirection, language.layoutDirection)
                .environment(\.locale, language.locale)
                .environment(\.movementLanguage, language)
        }
        .modelContainer(rides)
    }
}
