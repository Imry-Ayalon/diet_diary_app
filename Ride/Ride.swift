import Foundation
import CoreLocation
import MapKit
import SwiftData

struct TrackPoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension Array where Element == TrackPoint {
    func routeRegion(padding: Double = 1.4) -> MKCoordinateRegion? {
        guard let first else { return nil }
        let latitudes = map(\.latitude)
        let longitudes = map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: Swift.max((maxLat - minLat) * padding, 0.01),
            longitudeDelta: Swift.max((maxLon - minLon) * padding, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

@Model
final class Ride {
    var date: Date
    var distanceMeters: Double
    var movingSeconds: Double
    var calories: Int?
    var ascentMeters: Double?
    var maxSpeedMetersPerSecond: Double?
    var kindRaw: String?
    var trackData: Data

    init(
        date: Date = Date(),
        distanceMeters: Double,
        movingSeconds: Double,
        calories: Int?,
        ascentMeters: Double = 0,
        maxSpeedMetersPerSecond: Double = 0,
        kind: ActivityKind = .ride,
        track: [TrackPoint]
    ) {
        self.date = date
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.calories = calories
        self.ascentMeters = ascentMeters
        self.maxSpeedMetersPerSecond = maxSpeedMetersPerSecond
        self.kindRaw = kind.rawValue
        self.trackData = (try? JSONEncoder().encode(track)) ?? Data()
    }

    var kind: ActivityKind {
        ActivityKind(rawValue: kindRaw ?? "") ?? .ride
    }

    var track: [TrackPoint] {
        (try? JSONDecoder().decode([TrackPoint].self, from: trackData)) ?? []
    }
}

enum RideLibrary {
    static func makeContainer() throws -> ModelContainer {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DiaryStore.appGroupID) else {
            throw DiaryStoreError.missingAppGroup
        }
        let storeURL = directory.appending(path: "Rides.store")
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: Ride.self, configurations: configuration)
    }
}

enum DiaryStoreError: Error {
    case missingAppGroup
}

enum ActivityKind: String, CaseIterable, Identifiable {
    case ride
    case run
    case walk

    var id: String { rawValue }

    func label(_ language: MovementLanguage) -> String {
        switch (self, language) {
        case (.ride, .hebrew): "רכיבה"
        case (.ride, .english): "Ride"
        case (.run, .hebrew): "ריצה"
        case (.run, .english): "Run"
        case (.walk, .hebrew): "הליכה"
        case (.walk, .english): "Walk"
        }
    }

    func moving(_ language: MovementLanguage) -> String {
        switch (self, language) {
        case (.ride, .hebrew): "רוכב"
        case (.ride, .english): "Riding"
        case (.run, .hebrew): "רץ"
        case (.run, .english): "Running"
        case (.walk, .hebrew): "הולך"
        case (.walk, .english): "Walking"
        }
    }

    func resume(_ language: MovementLanguage) -> String {
        switch (self, language) {
        case (.ride, .hebrew): "המשך לרכוב"
        case (.ride, .english): "Keep riding"
        case (.run, .hebrew): "המשך לרוץ"
        case (.run, .english): "Keep running"
        case (.walk, .hebrew): "המשך ללכת"
        case (.walk, .english): "Keep walking"
        }
    }

    /// Always Hebrew so the meal diary row matches existing workout titles.
    var diaryTitle: String {
        switch self {
        case .ride: "רכיבת אופניים"
        case .run: "ריצה"
        case .walk: "הליכה"
        }
    }

    var symbol: String {
        switch self {
        case .ride: "bicycle"
        case .run: "figure.run"
        case .walk: "figure.walk"
        }
    }

    var slowSpeed: Double {
        switch self {
        case .ride: 0.8
        case .run: 0.5
        case .walk: 0.3
        }
    }

    var resumeSpeed: Double {
        switch self {
        case .ride: 2.0
        case .run: 1.3
        case .walk: 0.8
        }
    }

    func definite(_ language: MovementLanguage) -> String {
        switch (self, language) {
        case (.ride, .hebrew): "הרכיבה"
        case (.ride, .english): "the ride"
        case (.run, .hebrew): "הריצה"
        case (.run, .english): "the run"
        case (.walk, .hebrew): "ההליכה"
        case (.walk, .english): "the walk"
        }
    }

    func posterTitle(at date: Date, language: MovementLanguage) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if language == .english {
            let time: String
            switch hour {
            case 5..<12: time = "Morning"
            case 12..<17: time = "Afternoon"
            case 17..<22: time = "Evening"
            default: time = "Night"
            }
            switch self {
            case .ride: return "\(time) ride"
            case .run: return "\(time) run"
            case .walk: return "\(time) walk"
            }
        }
        let time: String
        switch hour {
        case 5..<12: time = "בוקר"
        case 12..<17: time = "צהריים"
        case 17..<22: time = "ערב"
        default: time = "לילה"
        }
        switch self {
        case .ride: return "רכיבת \(time)"
        case .run: return "ריצת \(time)"
        case .walk: return "הליכת \(time)"
        }
    }
}

enum RideCalories {
    static func estimate(distanceMeters: Double, movingSeconds: TimeInterval, weightKg: Double, kind: ActivityKind) -> Int? {
        guard weightKg > 0, movingSeconds > 0, distanceMeters > 0 else { return nil }
        let kilometersPerHour = (distanceMeters / 1000) / (movingSeconds / 3600)
        let met: Double
        switch kind {
        case .run: met = runningEffort(for: kilometersPerHour)
        case .ride: met = cyclingEffort(for: kilometersPerHour)
        case .walk: met = walkingEffort(for: kilometersPerHour)
        }
        let hours = movingSeconds / 3600
        return Int((met * weightKg * hours).rounded())
    }

    private static func cyclingEffort(for kilometersPerHour: Double) -> Double {
        switch kilometersPerHour {
        case ..<16: return 4
        case ..<19: return 6
        case ..<22: return 8
        case ..<26: return 10
        default: return 12
        }
    }

    private static func runningEffort(for kilometersPerHour: Double) -> Double {
        switch kilometersPerHour {
        case ..<8: return 8.3
        case ..<9.7: return 9.8
        case ..<11.3: return 11
        case ..<12.9: return 11.8
        case ..<14.5: return 12.8
        default: return 14.5
        }
    }

    private static func walkingEffort(for kilometersPerHour: Double) -> Double {
        switch kilometersPerHour {
        case ..<4: return 2.0
        case ..<5: return 3.5
        case ..<6.5: return 4.3
        case ..<7.5: return 5.0
        default: return 6.3
        }
    }
}

enum RideSummary {
    static func notes(
        distanceMeters: Double,
        movingSeconds: TimeInterval,
        ascentMeters: Double = 0,
        calories: Int?,
        language: MovementLanguage = .hebrew
    ) -> String {
        let minutes = Int((movingSeconds / 60).rounded())
        var notes: String
        if language == .english {
            notes = String(format: "%.1f km · %d min", distanceMeters / 1000, minutes)
            let climbed = Int(ascentMeters.rounded())
            if climbed > 0 {
                notes += " · \(climbed) m ascent"
            }
            if let calories {
                notes += " · ~\(calories) kcal"
            }
        } else {
            notes = String(format: "%.1f ק״מ · %d דק׳", distanceMeters / 1000, minutes)
            let climbed = Int(ascentMeters.rounded())
            if climbed > 0 {
                notes += " · \(climbed) מ׳ עלייה"
            }
            if let calories {
                notes += " · כ-\(calories) קק״ל"
            }
        }
        return notes
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    static func averageKilometersPerHour(distanceMeters: Double, movingSeconds: TimeInterval) -> Double {
        guard movingSeconds > 0 else { return 0 }
        return distanceMeters / movingSeconds * 3.6
    }
}

enum DiaryWorkout {
    static func add(
        _ kind: ActivityKind,
        on date: Date,
        distanceMeters: Double,
        movingSeconds: TimeInterval,
        ascentMeters: Double,
        calories: Int?,
        container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        context.insert(FoodEntry(
            title: kind.diaryTitle,
            notes: RideSummary.notes(
                distanceMeters: distanceMeters,
                movingSeconds: movingSeconds,
                ascentMeters: ascentMeters,
                calories: calories,
                language: .hebrew
            ),
            date: date,
            mealType: .workout
        ))
        try context.save()
    }

    static func remove(_ kind: ActivityKind, on date: Date, container: ModelContainer) {
        let context = ModelContext(container)
        guard let entries = try? context.fetch(FetchDescriptor<FoodEntry>()) else { return }
        guard let match = entries
            .filter({ $0.mealType == .workout && $0.title == kind.diaryTitle })
            .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }),
              abs(match.date.timeIntervalSince(date)) < 5
        else { return }
        context.delete(match)
        try? context.save()
    }
}
