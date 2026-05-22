import Combine
import Foundation
import UserNotifications

/// Manages driving alerts.
///
/// True app-blocking requires the `com.apple.developer.family-controls`
/// entitlement (Apple approval needed). Without it, we show a fullscreen
/// overlay and a persistent local notification to deter phone use while driving.
@MainActor
final class BlockingManager: ObservableObject {

    // MARK: - Published state

    @Published var isBlocking: Bool = false
    @Published var notificationsAuthorized: Bool = false

    // MARK: - Unused (kept for API compatibility with ContentView / SettingsView)

    var isAuthorized: Bool { true }
    var authorizationError: String? { nil }

    // MARK: - Init

    init() {
        Task { await checkNotificationStatus() }
    }

    // MARK: - Notification permission

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        notificationsAuthorized = granted
    }

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Blocking (overlay + notification)

    func applyBlocking() {
        guard !isBlocking else { return }
        isBlocking = true
        scheduleNotification()
    }

    func removeBlocking() {
        guard isBlocking else { return }
        isBlocking = false
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["driving"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["driving"])
    }

    // MARK: - Private

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notif.title", comment: "")
        content.body  = NSLocalizedString("notif.body",  comment: "")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "driving",
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
