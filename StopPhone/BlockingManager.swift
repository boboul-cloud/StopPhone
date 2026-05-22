import Combine
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Manages driving protection:
///  1. Screen Time blocking via FamilyControls + ManagedSettings
///  2. Fullscreen overlay in-app (handled by ContentView)
///  3. Local notification
@MainActor
final class BlockingManager: ObservableObject {

    @Published var isAuthorized: Bool = false
    @Published var isBlocking: Bool = false
    @Published var authorizationError: String?
    @Published var notificationsAuthorized: Bool = false
    @Published var activitySelection: FamilyActivitySelection = FamilyActivitySelection() {
        didSet { persistSelection() }
    }

    private let store = ManagedSettingsStore()
    private static let selectionKey = "stopphone_blocking_selection"

    init() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        loadSelection()
        if isAuthorized {
            isBlocking = store.shield.applicationCategories != nil
        }
        Task { await checkNotificationStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationError = nil
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
        }
        await requestNotificationAuthorization()
    }

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
        if isAuthorized {
            let hasCustom = !activitySelection.categoryTokens.isEmpty
                            || !activitySelection.applicationTokens.isEmpty
            if hasCustom {
                if !activitySelection.categoryTokens.isEmpty {
                    store.shield.applicationCategories = .specific(
                        activitySelection.categoryTokens, except: [])
                    store.shield.webDomainCategories = .specific(
                        activitySelection.categoryTokens, except: [])
                }
                if !activitySelection.applicationTokens.isEmpty {
                    store.shield.applications = activitySelection.applicationTokens
                }
            } else {
                store.shield.applicationCategories = .all(except: [])
            }
        }
        scheduleNotification()
        isBlocking = true
    }

    func removeBlocking() {
        guard isBlocking else { return }
        if isAuthorized { store.clearAllSettings() }
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: ["driving"])
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["driving"])
        isBlocking = false
    }

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notif.title", comment: "")
        content.body  = NSLocalizedString("notif.body",  comment: "")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "driving", content: content, trigger: nil)
        )
    }

    // MARK: - Persistence

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(activitySelection) else { return }
        UserDefaults.standard.set(data, forKey: Self.selectionKey)
    }

    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: Self.selectionKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        activitySelection = decoded
    }
}
