import Combine
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Manages driving protection:
///  1. Screen Time blocking via FamilyControls + ManagedSettings (requires entitlement)
///  2. Fullscreen overlay in-app
///  3. Local notification
@MainActor
final class BlockingManager: ObservableObject {

    // MARK: - Published state

    @Published var isAuthorized: Bool = false
    @Published var isBlocking: Bool = false
    @Published var authorizationError: String?
    @Published var notificationsAuthorized: Bool = false

    /// Apps/categories selected via FamilyActivityPicker. Empty = block all categories.
    @Published var activitySelection: FamilyActivitySelection = FamilyActivitySelection() {
        didSet { persistSelection() }
    }

    // MARK: - Private

    private let store = ManagedSettingsStore()
    private static let selectionKey = "stopphone_blocking_selection"

    // MARK: - Init

    init() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        loadSelection()
        if isAuthorized {
            isBlocking = store.shield.applicationCategories != nil
        }
        Task { await checkNotificationStatus() }
    }

    // MARK: - FamilyControls authorization

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

        // --- Screen Time blocking ---
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
                // Default: block every app category
                store.shield.applicationCategories = .all(except: [])
            }
        }

        // --- Notification ---
        scheduleNotification()

        isBlocking = true
    }

    func removeBlocking() {
        guard isBlocking else { return }

        if isAuthorized {
            store.clearAllSettings()
        }
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
