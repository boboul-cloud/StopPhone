import SwiftUI

@main
struct StopPhoneApp: App {

    @StateObject private var speedMonitor = SpeedMonitor()
    @StateObject private var blockingManager = BlockingManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(speedMonitor)
                .environmentObject(blockingManager)
        }
    }
}
