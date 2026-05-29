import SwiftUI

@main
struct StopPhoneApp: App {

    @StateObject private var speedMonitor = SpeedMonitor()
    @StateObject private var blockingManager = BlockingManager()
    @StateObject private var bluetoothMonitor = BluetoothMonitor()
    @StateObject private var tripStore = TripStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(speedMonitor)
                .environmentObject(blockingManager)
                .environmentObject(bluetoothMonitor)
                .environmentObject(tripStore)
                .onAppear {
                    // Wire trip recording across managers.
                    blockingManager.tripStore = tripStore
                    speedMonitor.onSpeedSample = { [weak blockingManager] kmh in
                        blockingManager?.sampleSpeed(kmh)
                    }
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    // MARK: - URL scheme handling
    // stopphone://activate  → enables protection + applies blocking immediately
    // stopphone://deactivate → removes blocking + disables protection
    private func handleURL(_ url: URL) {
        guard url.scheme == "stopphone" else { return }
        switch url.host {
        case "activate":
            speedMonitor.setEnabled(true)
            blockingManager.applyBlocking(trigger: .bluetooth)
        case "deactivate":
            blockingManager.removeBlocking()
            speedMonitor.setEnabled(false)
        default:
            break
        }
    }
}
