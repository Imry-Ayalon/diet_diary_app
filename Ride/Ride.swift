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
    var trackData: Data

    init(
        date: Date = Date(),
        distanceMeters: Double,
        movingSeconds: Double,
        calories: Int?,
        ascentMeters: Double = 0,
        maxSpeedMetersPerSecond: Double = 0,
        track: [TrackPoint]
    ) {
        self.date = date
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.calories = calories
        self.ascentMeters = ascentMeters
        self.maxSpeedMetersPerSecond = maxSpeedMetersPerSecond
        self.trackData = (try? JSONEncoder().encode(track)) ?? Data()
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

enum RideCalories {
    static func estimate(distanceMeters: Double, movingSeconds: TimeInterval, weightKg: Double) -> Int? {
        guard weightKg > 0, movingSeconds > 0, distanceMeters > 0 else { return nil }
        let kilometersPerHour = (distanceMeters / 1000) / (movingSeconds / 3600)
        let met = effort(for: kilometersPerHour)
        let hours = movingSeconds / 3600
        return Int((met * weightKg * hours).rounded())
    }

    private static func effort(for kilometersPerHour: Double) -> Double {
        switch kilometersPerHour {
        case ..<16: return 4
        case ..<19: return 6
        case ..<22: return 8
        case ..<26: return 10
        default: return 12
        }
    }
}

enum RideSummary {
    static func notes(distanceMeters: Double, movingSeconds: TimeInterval, ascentMeters: Double = 0, calories: Int?) -> String {
        let minutes = Int((movingSeconds / 60).rounded())
        var notes = String(format: "%.1f ק״מ · %d דק׳", distanceMeters / 1000, minutes)
        let climbed = Int(ascentMeters.rounded())
        if climbed > 0 {
            notes += " · \(climbed) מ׳ עלייה"
        }
        if let calories {
            notes += " · כ-\(calories) קק״ל"
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
    static let rideTitle = "רכיבת אופניים"

    static func addRide(
        on date: Date,
        distanceMeters: Double,
        movingSeconds: TimeInterval,
        ascentMeters: Double,
        calories: Int?,
        container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        context.insert(FoodEntry(
            title: rideTitle,
            notes: RideSummary.notes(
                distanceMeters: distanceMeters,
                movingSeconds: movingSeconds,
                ascentMeters: ascentMeters,
                calories: calories
            ),
            date: date,
            mealType: .workout
        ))
        try context.save()
    }

    static func removeRide(on date: Date, container: ModelContainer) {
        let context = ModelContext(container)
        guard let entries = try? context.fetch(FetchDescriptor<FoodEntry>()) else { return }
        guard let match = entries
            .filter({ $0.mealType == .workout && $0.title == rideTitle })
            .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }),
              abs(match.date.timeIntervalSince(date)) < 5
        else { return }
        context.delete(match)
        try? context.save()
    }
}
