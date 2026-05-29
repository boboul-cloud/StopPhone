import AVFoundation
import Combine
import Foundation

/// Detects car Bluetooth audio connections via AVAudioSession route changes (HFP / A2DP).
/// Classic Bluetooth (used by car audio) is not accessible through CoreBluetooth on iOS,
/// but audio route notifications reliably fire when a phone connects to a car's hands-free system.
@MainActor
final class BluetoothMonitor: ObservableObject {

    // MARK: - Published state

    /// True when a qualifying Bluetooth audio device is connected.
    @Published var isCarConnected: Bool = false

    /// Name of the Bluetooth audio device currently connected (nil if none).
    @Published var currentBluetoothDeviceName: String?

    /// Whether the Bluetooth trigger is active.
    @Published var bluetoothTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(bluetoothTriggerEnabled, forKey: UDKey.btTrigger)
            updateCurrentState()
        }
    }

    /// Optional device name to match. When nil, any BT audio device triggers activation.
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

    // MARK: - Init

    init() {
        bluetoothTriggerEnabled = UserDefaults.standard.bool(forKey: UDKey.btTrigger)
        targetDeviceName = UserDefaults.standard.string(forKey: UDKey.btDevice)
        setupNotifications()
        updateCurrentState()
    }

    // MARK: - Public API

    /// Save the currently connected BT device as the target device.
    func learnCurrentDevice() {
        targetDeviceName = currentBluetoothDeviceName
    }

    /// Clear the pinned device — any Bluetooth will trigger activation.
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

        // Bluetooth audio port types that car hands-free systems use
        let btPort = outputs.first(where: {
            $0.portType == .bluetoothHFP
            || $0.portType == .bluetoothA2DP
            || $0.portType == .bluetoothLE
        })

        currentBluetoothDeviceName = btPort?.portName

        guard bluetoothTriggerEnabled else {
            isCarConnected = false
            return
        }

        if let port = btPort {
            if let target = targetDeviceName, !target.isEmpty {
                isCarConnected = port.portName.localizedCaseInsensitiveContains(target)
            } else {
                isCarConnected = true   // any BT audio device
            }
        } else {
            isCarConnected = false
        }
    }
}
