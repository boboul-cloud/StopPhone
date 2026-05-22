import CoreLocation
import Combine

/// Monitors device speed via GPS. Published properties are always updated on the MainActor.
@MainActor
final class SpeedMonitor: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var currentSpeedKmh: Double = 0
    @Published var isAboveThreshold: Bool = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isEnabled: Bool = false

    // MARK: - Configuration

    let speedThreshold: Double = 15.0   // km/h

    // MARK: - Private

    private let locationManager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5                   // update every 5 m
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public API

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
            currentSpeedKmh = 0
            isAboveThreshold = false
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SpeedMonitor: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let loc = locations.last else { return }
        // CLLocation.speed is in m/s; negative means invalid
        let kmh = loc.speed >= 0 ? loc.speed * 3.6 : 0

        Task { @MainActor in
            self.currentSpeedKmh = kmh
            self.isAboveThreshold = kmh >= self.speedThreshold
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            // Auto-start if already enabled and permission just granted
            if self.isEnabled,
               status == .authorizedAlways || status == .authorizedWhenInUse {
                self.locationManager.startUpdatingLocation()
            }
        }
    }
}
