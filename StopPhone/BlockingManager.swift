import Combine
import FamilyControls
import Foundation
import ManagedSettings

/// Manages Screen Time blocking via FamilyControls + ManagedSettings.
///
/// Two blocking modes:
///  - Default  : shields every app category (.all) when no custom selection exists.
///  - Custom   : shields only the apps/categories the user picked via FamilyActivityPicker.
///
/// NOTE: the `com.apple.developer.family-controls` entitlement must be
/// added to the provisioning profile.
@MainActor
final class BlockingManager: ObservableObject {

    // MARK: - Published state

    @Published var isAuthorized: Bool = false
    @Published var isBlocking: Bool = false
    @Published var authorizationError: String?

    /// The apps/categories the user selected via FamilyActivityPicker.
    /// Persisted across launches. Empty = block all categories.
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
    }

    // MARK: - Blocking

    func applyBlocking() {
        guard isAuthorized else { return }

        let hasCustomSelection = !activitySelection.categoryTokens.isEmpty
                                 || !activitySelection.applicationTokens.isEmpty

        if hasCustomSelection {
            if !activitySelection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(
                    activitySelection.categoryTokens,
                    except: []
                )
                store.shield.webDomainCategories = .specific(
                    activitySelection.categoryTokens,
                    except: []
                )
            }
            if !activitySelection.applicationTokens.isEmpty {
                store.shield.applications = activitySelection.applicationTokens
            }
        } else {
            // Default: shield all app categories (shows a driving warning overlay)
            store.shield.applicationCategories = .all(except: [])
        }

        isBlocking = true
    }

    func removeBlocking() {
        store.clearAllSettings()
        isBlocking = false
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
