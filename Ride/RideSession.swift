import Foundation
import CoreLocation

struct RideSnapshot {
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
    }

    private(set) var phase: Phase = .idle
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

    private let slowSpeed = 0.8
    private let resumeSpeed = 2.0
    private let slowLimit = 4
    private let maxAccuracy = 25.0

    func start() {
        resetMeasurements()
        phase = .riding
        locationDenied = false
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.requestWhenInUseAuthorization()
        beginUpdatesIfAllowed()
        startTimer()
    }

    func pauseForBreak() {
        guard phase == .riding || phase == .trafficPause else { return }
        phase = .breakPause
        slowSeconds = 0
        lastLocation = nil
        speedMetersPerSecond = 0
    }

    func resumeFromBreak() {
        guard phase == .breakPause else { return }
        phase = .riding
        slowSeconds = 0
        lastLocation = nil
    }

    func discard() {
        guard phase != .idle else { return }
        stop()
    }

    func finish() -> RideSnapshot? {
        guard phase != .idle else { return nil }
        let snapshot = RideSnapshot(
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
        resetMeasurements()
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
            if speedMetersPerSecond < slowSpeed {
                slowSeconds += 1
                if slowSeconds >= slowLimit {
                    movingSeconds = max(0, movingSeconds - Double(slowLimit))
                    phase = .trafficPause
                    slowSeconds = 0
                    lastLocation = nil
                }
            } else {
                slowSeconds = 0
            }
        }
    }

    private func absorb(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maxAccuracy else { return }
        hasFix = true
        guard location.speed >= 0 else { return }
        speedMetersPerSecond = location.speed
        if phase == .riding, location.speed < 28 {
            maxSpeedMetersPerSecond = max(maxSpeedMetersPerSecond, location.speed)
        }
        recordAscent(location)

        if phase == .trafficPause, location.speed > resumeSpeed {
            phase = .riding
            slowSeconds = 0
            lastLocation = nil
        }

        guard phase == .riding, location.speed >= slowSpeed else { return }
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
