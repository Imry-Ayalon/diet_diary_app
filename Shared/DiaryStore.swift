import Foundation
import SwiftData

enum DiaryStore {
    static let appGroupID = "group.com.imryayalon.MyApp12345"

    static func makeContainer(migratingLegacy: Bool) throws -> ModelContainer {
        let directory = try groupDirectory()
        let storeURL = directory.appending(path: "Diary.store")
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: FoodEntry.self, configurations: configuration)
        if migratingLegacy {
            migrateLegacyMealsIfNeeded(into: container, directory: directory)
        }
        return container
    }

    private static func groupDirectory() throws -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw StoreError.missingAppGroup
        }
        return url
    }

    private static func migrateLegacyMealsIfNeeded(into container: ModelContainer, directory: URL) {
        let marker = directory.appending(path: "diary-migrated")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }

        let legacyURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "default.store")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            try? Data().write(to: marker)
            return
        }

        let legacyConfiguration = ModelConfiguration(url: legacyURL, cloudKitDatabase: .none)
        guard let legacyContainer = try? ModelContainer(for: FoodEntry.self, configurations: legacyConfiguration) else {
            return
        }

        let legacyContext = ModelContext(legacyContainer)
        let entries = (try? legacyContext.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let destination = ModelContext(container)
        for entry in entries {
            destination.insert(FoodEntry(
                title: entry.title,
                notes: entry.notes,
                date: entry.date,
                mealType: entry.mealType,
                imageData: entry.imageData,
                featurePrint: entry.featurePrint
            ))
        }
        do {
            if !entries.isEmpty {
                try destination.save()
            }
            try Data().write(to: marker)
        } catch {
            return
        }
    }

    private enum StoreError: Error {
        case missingAppGroup
    }
}
