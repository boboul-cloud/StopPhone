import Combine
import Foundation
import UserNotifications

/// Manages driving protection:
///  1. Fullscreen overlay in-app (handled by ContentView)
///  2. Local notification
@MainActor
final class BlockingManager: ObservableObject {

    @Published var isBlocking: Bool = false
    @Published var notificationsAuthorized: Bool = false

    init() {
        Task { await checkNotificationStatus() }
    }

    // MARK: - Notification authorization

    func requestNotificationAuthorization() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        notificationsAuthorized = granted
    }

    private func checkNotificationStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = s.authorizationStatus == .authorized
    }

    // MARK: - Blocking

    func applyBlocking() {
        guard !isBlocking else { return }
        scheduleNotification()
        isBlocking = true
    }

    func removeBlocking() {
        guard isBlocking else { return }
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: ["driving"])
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["driving"])
        isBlocking = false
    }

    // MARK: - Notification

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notif.title", comment: "")
        content.body  = NSLocalizedString("notif.body",  comment: "")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "driving", content: content, trigger: nil)
        )
    }
}
