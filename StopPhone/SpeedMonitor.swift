import CoreLocation
import Combine

/// Monitors device speed via GPS. Published properties are always updated on the MainActor.
@MainActor
final class SpeedMonitor: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var currentSpeedKmh: Double = 0
    @Published var isAboveThreshold: Bool = false {
        didSet {
            UserDefaults.standard.set(isAboveThreshold, forKey: UDKey.aboveThreshold)
        }
    }
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isEnabled: Bool = false
    @Published var isDemoMode: Bool = false

    /// 0 = auto-disable off, else minutes of stationary time before turning protection off.
    @Published var autoDisableMinutes: Int {
        didSet { UserDefaults.standard.set(autoDisableMinutes, forKey: UDKey.autoDisableMinutes) }
    }

    @Published var speedThreshold: Double {
        didSet {
            UserDefaults.standard.set(speedThreshold, forKey: UDKey.speedThreshold)
            if isEnabled {
                isAboveThreshold = currentSpeedKmh >= speedThreshold
            }
        }
    }

    // MARK: - Configuration
    let demoSpeedKmh: Double = 65

    // MARK: - Private

    private let locationManager = CLLocationManager()
    /// Callback invoked on each GPS sample (km/h) — wired to BlockingManager.sampleSpeed.
    var onSpeedSample: ((Double) -> Void)?
    private var lastMotionDate: Date = Date()
    private var autoDisableTimer: Timer?

    // MARK: - Init

    override init() {
        let saved = UserDefaults.standard.double(forKey: UDKey.speedThreshold)
        speedThreshold = saved > 0 ? saved : AppConstants.defaultSpeedThreshold
        autoDisableMinutes = UserDefaults.standard.integer(forKey: UDKey.autoDisableMinutes)
        super.init()
        isEnabled = UserDefaults.standard.bool(forKey: UDKey.isEnabled)
        isAboveThreshold = UserDefaults.standard.bool(forKey: UDKey.aboveThreshold)

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest          // was BestForNavigation (battery hog)
        locationManager.distanceFilter = AppConstants.gpsDistanceFilter    // was none — saves battery
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus

        if isEnabled {
            startLocationServices()
        }
        startAutoDisableTimer()
    }

    // MARK: - Public API

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: UDKey.isEnabled)
        if enabled {
            lastMotionDate = Date()
            startLocationServices()
        } else {
            locationManager.stopUpdatingLocation()
            locationManager.stopMonitoringSignificantLocationChanges()
            currentSpeedKmh = 0
            isAboveThreshold = false
            UserDefaults.standard.removeObject(forKey: UDKey.aboveThreshold)
        }
    }

    private func startLocationServices() {
        guard authorizationStatus == .authorizedAlways
              || authorizationStatus == .authorizedWhenInUse else { return }
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
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

    // MARK: - Auto-disable

    private func startAutoDisableTimer() {
        autoDisableTimer?.invalidate()
        // Check every minute
        autoDisableTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateAutoDisable() }
        }
    }

    private func evaluateAutoDisable() {
        guard isEnabled, !isDemoMode, autoDisableMinutes > 0 else { return }
        let elapsedMin = Date().timeIntervalSince(lastMotionDate) / 60
        if elapsedMin >= Double(autoDisableMinutes) {
            setEnabled(false)
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
        let rawKmh = loc.speed >= 0 ? loc.speed * 3.6 : 0
        let kmh = rawKmh < AppConstants.speedNoiseFloor ? 0.0 : rawKmh

        Task { @MainActor in
            guard !self.isDemoMode else { return }
            self.currentSpeedKmh = kmh
            self.onSpeedSample?(kmh)
            if kmh > 0 { self.lastMotionDate = Date() }
            guard self.isEnabled else { return }
            if self.isAboveThreshold {
                if kmh < max(self.speedThreshold - AppConstants.hysteresisGap, 0) {
                    self.isAboveThreshold = false
                }
            } else {
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
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                if self.isEnabled { self.startLocationServices() }
            case .denied, .restricted:
                // Permission révoquée → on désactive proprement la protection
                // pour ne pas laisser le toggle ON sans GPS.
                if self.isEnabled { self.setEnabled(false) }
            default:
                break
            }
        }
    }
}
