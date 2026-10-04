import Foundation
import CoreLocation

struct RideSnapshot {
    var kind: ActivityKind
    var distanceMeters: Double
    var movingSeconds: TimeInterval
    var ascentMeters: Double
    var maxSpeedMetersPerSecond: Double
    var track: [TrackPoint]
}

@Observable
final class RideSession: NSObject, CLLocationManagerDelegate {
    enum Phase: Equatable {
        case idle
        case riding
        case trafficPause
        case breakPause

        fileprivate var storedName: String {
            switch self {
            case .idle: "idle"
            case .riding: "riding"
            case .trafficPause: "trafficPause"
            case .breakPause: "breakPause"
            }
        }

        fileprivate init?(stored name: String) {
            switch name {
            case "riding": self = .riding
            case "trafficPause": self = .trafficPause
            case "breakPause": self = .breakPause
            default: return nil
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var kind: ActivityKind = .ride
    private(set) var distanceMeters = 0.0
    private(set) var movingSeconds = 0.0
    private(set) var speedMetersPerSecond = 0.0
    private(set) var ascentMeters = 0.0
    private(set) var maxSpeedMetersPerSecond = 0.0
    private(set) var track: [TrackPoint] = []
    private(set) var locationDenied = false

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var lastLocation: CLLocation?
    private var smoothedAltitude: Double?
    private var countedAltitude: Double?
    private var slowSeconds = 0
    private var hasFix = false

    private let slowLimit = 4
    private let maxAccuracy = 25.0
    private var lastSavedAt = Date.distantPast

    func start(_ kind: ActivityKind) {
        resetMeasurements()
        self.kind = kind
        phase = .riding
        locationDenied = false
        ensureTracking()
        saveProgress()
    }

    func restoreIfNeeded() {
        guard phase == .idle, let draft = ActiveRideDraftStore.load() else { return }
        kind = ActivityKind(rawValue: draft.kind) ?? .ride
        distanceMeters = draft.distanceMeters
        movingSeconds = draft.movingSeconds
        ascentMeters = draft.ascentMeters
        maxSpeedMetersPerSecond = draft.maxSpeedMetersPerSecond
        track = draft.track
        smoothedAltitude = draft.smoothedAltitude
        countedAltitude = draft.countedAltitude
        phase = Phase(stored: draft.phase) ?? .breakPause
        locationDenied = false
        if phase == .breakPause {
            speedMetersPerSecond = 0
        } else {
            ensureTracking()
        }
    }

    func pauseForBreak() {
        guard phase == .riding || phase == .trafficPause else { return }
        phase = .breakPause
        slowSeconds = 0
        lastLocation = nil
        speedMetersPerSecond = 0
        saveProgress()
    }

    func resumeFromBreak() {
        guard phase == .breakPause else { return }
        phase = .riding
        slowSeconds = 0
        lastLocation = nil
        ensureTracking()
        saveProgress()
    }

    func saveProgress() {
        guard phase != .idle else { return }
        lastSavedAt = Date()
        ActiveRideDraftStore.save(ActiveRideDraft(
            phase: phase.storedName,
            kind: kind.rawValue,
            distanceMeters: distanceMeters,
            movingSeconds: movingSeconds,
            ascentMeters: ascentMeters,
            maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
            track: track,
            smoothedAltitude: smoothedAltitude,
            countedAltitude: countedAltitude
        ))
    }

    func discard() {
        guard phase != .idle else { return }
        stop()
    }

    func finish() -> RideSnapshot? {
        guard phase != .idle else { return nil }
        let snapshot = RideSnapshot(
            kind: kind,
            distanceMeters: distanceMeters,
            movingSeconds: movingSeconds,
            ascentMeters: ascentMeters,
            maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
            track: track
        )
        stop()
        return snapshot
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        phase = .idle
        kind = .ride
        resetMeasurements()
        ActiveRideDraftStore.clear()
    }

    private func resetMeasurements() {
        distanceMeters = 0
        movingSeconds = 0
        speedMetersPerSecond = 0
        ascentMeters = 0
        maxSpeedMetersPerSecond = 0
        track = []
        lastLocation = nil
        smoothedAltitude = nil
        countedAltitude = nil
        slowSeconds = 0
        hasFix = false
    }

    private func ensureTracking() {
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.requestWhenInUseAuthorization()
        beginUpdatesIfAllowed()
        startTimer()
    }

    private func saveProgressIfDue() {
        guard Date().timeIntervalSince(lastSavedAt) >= 15 else { return }
        saveProgress()
    }

    private func beginUpdatesIfAllowed() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            enableBackgroundUpdatesIfSupported()
            manager.startUpdatingLocation()
        case .denied, .restricted:
            locationDenied = true
        default:
            break
        }
    }

    private func enableBackgroundUpdatesIfSupported() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        guard modes?.contains("location") == true else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let session = self
            Task { @MainActor in
                session?.tick()
            }
        }
    }

    private func tick() {
        guard hasFix else { return }
        if phase == .riding {
            movingSeconds += 1
            if speedMetersPerSecond < kind.slowSpeed {
                slowSeconds += 1
                if slowSeconds >= slowLimit {
                    movingSeconds = max(0, movingSeconds - Double(slowLimit))
                    phase = .trafficPause
                    slowSeconds = 0
                    lastLocation = nil
                    saveProgress()
                }
            } else {
                slowSeconds = 0
            }
        }
        saveProgressIfDue()
    }

    private func absorb(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maxAccuracy else { return }
        hasFix = true
        defer { saveProgressIfDue() }
        guard location.speed >= 0 else { return }
        speedMetersPerSecond = location.speed
        if phase == .riding, location.speed < 28 {
            maxSpeedMetersPerSecond = max(maxSpeedMetersPerSecond, location.speed)
        }
        recordAscent(location)

        if phase == .trafficPause, location.speed > kind.resumeSpeed {
            phase = .riding
            slowSeconds = 0
            lastLocation = nil
        }

        guard phase == .riding, location.speed >= kind.slowSpeed else { return }
        if let lastLocation {
            let gap = location.distance(from: lastLocation)
            if gap >= 1, gap < 80 {
                distanceMeters += gap
            }
        }
        lastLocation = location
        let altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
        track.append(TrackPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, altitude: altitude))
    }

    private func recordAscent(_ location: CLLocation) {
        guard phase == .riding || phase == .trafficPause else { return }
        guard location.verticalAccuracy >= 0, location.verticalAccuracy <= 15 else { return }
        let altitude = location.altitude
        guard let smoothed = smoothedAltitude else {
            smoothedAltitude = altitude
            countedAltitude = altitude
            return
        }
        let next = smoothed * 0.8 + altitude * 0.2
        smoothedAltitude = next
        guard let counted = countedAltitude else {
            countedAltitude = next
            return
        }
        let rise = next - counted
        if rise >= 1.2 {
            ascentMeters += rise
            countedAltitude = next
        } else if rise <= -1.2 {
            countedAltitude = next
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard phase != .idle else { return }
            beginUpdatesIfAllowed()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locations = locations
        Task { @MainActor in
            locations.forEach(absorb)
        }
    }
}

private struct ActiveRideDraft: Codable {
    var phase: String
    var kind: String
    var distanceMeters: Double
    var movingSeconds: Double
    var ascentMeters: Double
    var maxSpeedMetersPerSecond: Double
    var track: [TrackPoint]
    var smoothedAltitude: Double?
    var countedAltitude: Double?
}

private enum ActiveRideDraftStore {
    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: DiaryStore.appGroupID)?
            .appending(path: "active-ride.json")
    }

    static func load() -> ActiveRideDraft? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        guard let draft = try? JSONDecoder().decode(ActiveRideDraft.self, from: data) else {
            clear()
            return nil
        }
        return draft
    }

    static func save(_ draft: ActiveRideDraft) {
        guard let url, let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
