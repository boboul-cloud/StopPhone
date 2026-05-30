import AVFoundation
import Combine
import Foundation

/// Detects car Bluetooth audio connections via AVAudioSession route changes (HFP / A2DP).
/// Supports multiple registered vehicles via `VehicleStore` — each vehicle is identified
/// by its Bluetooth audio device name.
@MainActor
final class BluetoothMonitor: ObservableObject {

    // MARK: - Published state

    /// True when a qualifying Bluetooth audio device is connected and the trigger is active.
    @Published var isCarConnected: Bool = false

    /// Name of the Bluetooth audio device currently connected (nil if none).
    @Published var currentBluetoothDeviceName: String?

    /// The vehicle currently matched against the connected Bluetooth device, if any.
    @Published var currentVehicleID: UUID?

    /// Whether the Bluetooth trigger is active.
    @Published var bluetoothTriggerEnabled: Bool {
        didSet {
            UserDefaults.standard.set(bluetoothTriggerEnabled, forKey: UDKey.btTrigger)
            updateCurrentState()
        }
    }

    /// Legacy single pinned device name (still honored for users upgrading from v1).
    /// When the user has registered Vehicles, those take priority over this.
    @Published var targetDeviceName: String? {
        didSet {
            if let name = targetDeviceName {
                UserDefaults.standard.set(name, forKey: UDKey.btDevice)
            } else {
                UserDefaults.standard.removeObject(forKey: UDKey.btDevice)
            }
            updateCurrentState()
        }
    }

    /// Reference to the vehicles store — when set, BT matching considers all vehicles.
    weak var vehicleStore: VehicleStore? {
        didSet {
            vehicleStoreCancellable = vehicleStore?.objectWillChange.sink { [weak self] _ in
                Task { @MainActor in self?.updateCurrentState() }
            }
            updateCurrentState()
        }
    }
    private var vehicleStoreCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        bluetoothTriggerEnabled = UserDefaults.standard.bool(forKey: UDKey.btTrigger)
        targetDeviceName = UserDefaults.standard.string(forKey: UDKey.btDevice)
        setupNotifications()
        updateCurrentState()
    }

    // MARK: - Public API

    /// Save the currently connected BT device as the legacy single target (used in Settings fallback).
    func learnCurrentDevice() {
        targetDeviceName = currentBluetoothDeviceName
    }

    /// Clear the legacy pinned device.
    func clearTargetDevice() {
        targetDeviceName = nil
    }

    // MARK: - Private

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private nonisolated func audioRouteChanged(_ notification: Notification) {
        Task { @MainActor in self.updateCurrentState() }
    }

    private func updateCurrentState() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs

        let btPort = outputs.first(where: {
            $0.portType == .bluetoothHFP
            || $0.portType == .bluetoothA2DP
            || $0.portType == .bluetoothLE
        })

        currentBluetoothDeviceName = btPort?.portName

        guard bluetoothTriggerEnabled else {
            isCarConnected = false
            currentVehicleID = nil
            return
        }

        guard let port = btPort else {
            isCarConnected = false
            currentVehicleID = nil
            return
        }

        // 1. Match against registered vehicles first.
        if let store = vehicleStore, !store.vehicles.isEmpty {
            if let v = store.matchingVehicle(for: port.portName) {
                currentVehicleID = v.id
                isCarConnected = true
                return
            }
            // No registered vehicle matches — also honor the legacy single target if any.
            if let target = targetDeviceName, !target.isEmpty {
                currentVehicleID = nil
                isCarConnected = port.portName.localizedCaseInsensitiveContains(target)
                return
            }
            // Vehicles registered but none matched → don't trigger blindly.
            currentVehicleID = nil
            isCarConnected = false
            return
        }

        // 2. Legacy behaviour: pinned single device, or "any BT".
        currentVehicleID = nil
        if let target = targetDeviceName, !target.isEmpty {
            isCarConnected = port.portName.localizedCaseInsensitiveContains(target)
        } else {
            isCarConnected = true
        }
    }
}
