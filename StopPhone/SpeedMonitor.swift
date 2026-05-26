import CoreLocation
import Combine

/// Monitors device speed via GPS. Published properties are always updated on the MainActor.
@MainActor
final class SpeedMonitor: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var currentSpeedKmh: Double = 0
    @Published var isAboveThreshold: Bool = false {
        didSet {
            // Persist so the value survives process termination.
            // On relaunch (foreground or background), the Combine chain
            // starts from the last known state, preventing a premature unblock.
            UserDefaults.standard.set(isAboveThreshold, forKey: "stopphone_above_threshold")
        }
    }
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isEnabled: Bool = false  // loaded from UserDefaults in init
    @Published var isDemoMode: Bool = false

    // MARK: - Configuration

    /// GPS anti-flutter: deactivate only when speed drops this many km/h below the threshold.
    private let hysteresisGap: Double = 5.0
    let demoSpeedKmh: Double = 65

    @Published var speedThreshold: Double {
        didSet {
            UserDefaults.standard.set(speedThreshold, forKey: "stopphone_speed_threshold")
            // Re-evaluate immediately with the new threshold (user action, no hysteresis needed)
            if isEnabled {
                isAboveThreshold = currentSpeedKmh >= speedThreshold
            }
        }
    }

    // MARK: - Private

    private let locationManager = CLLocationManager()

    // MARK: - Init

    override init() {
        let saved = UserDefaults.standard.double(forKey: "stopphone_speed_threshold")
        speedThreshold = saved > 0 ? saved : 15.0
        super.init()
        isEnabled = UserDefaults.standard.bool(forKey: "stopphone_is_enabled")
        // Restore last known state to avoid a premature unblock on relaunch
        // before the first GPS fix arrives.
        isAboveThreshold = UserDefaults.standard.bool(forKey: "stopphone_above_threshold")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone  // always update — needed to reach 0 when stopped
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
        // Resume location tracking if protection was active before quit.
        // startMonitoringSignificantLocationChanges lets iOS relaunch the app
        // in the background after termination so blocking can be auto-removed
        // when the user has stopped driving.
        if isEnabled {
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }

    // MARK: - Public API

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "stopphone_is_enabled")
        if enabled {
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            locationManager.stopUpdatingLocation()
            locationManager.stopMonitoringSignificantLocationChanges()
            currentSpeedKmh = 0
            isAboveThreshold = false
            UserDefaults.standard.removeObject(forKey: "stopphone_above_threshold")
        }
    }

    // MARK: - Demo mode

    func startDemo() {
        isDemoMode = true
        if !isEnabled { setEnabled(true) }
        currentSpeedKmh = demoSpeedKmh
        isAboveThreshold = true
    }

    func stopDemo() {
        isDemoMode = false
        currentSpeedKmh = 0
        isAboveThreshold = false
    }
}

// MARK: - CLLocationManagerDelegate

extension SpeedMonitor: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let loc = locations.last else { return }
        // CLLocation.speed is in m/s; negative means invalid.
        // Apply a ~2 km/h noise floor to avoid GPS jitter showing non-zero when stopped.
        let rawKmh = loc.speed >= 0 ? loc.speed * 3.6 : 0
        let kmh = rawKmh < 2.0 ? 0.0 : rawKmh

        Task { @MainActor in
            guard !self.isDemoMode else { return }   // GPS frozen during demo
            self.currentSpeedKmh = kmh
            guard self.isEnabled else { return }
            if self.isAboveThreshold {
                // Already blocking: only release when clearly below threshold
                if kmh < max(self.speedThreshold - self.hysteresisGap, 0) {
                    self.isAboveThreshold = false
                }
            } else {
                // Not blocking: activate when threshold is reached
                if kmh >= self.speedThreshold {
                    self.isAboveThreshold = true
                }
            }
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
