import AVFoundation
import Combine
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Manages driving protection:
///  1. Screen Time blocking via FamilyControls + ManagedSettings
///  2. Fullscreen overlay in-app (handled by ContentView)
///  3. Local notification
///  4. Voice alert via AVSpeechSynthesizer (plays through car Bluetooth)
@MainActor
final class BlockingManager: ObservableObject {

    @Published var isAuthorized: Bool = false
    @Published var isBlocking: Bool = false
    @Published var authorizationError: String?
    @Published var totalBlockMode: Bool {
        didSet { UserDefaults.standard.set(totalBlockMode, forKey: "stopphone_total_block") }
    }
    @Published var blockingEpoch: Int = 0
    @Published var activitySelection: FamilyActivitySelection = FamilyActivitySelection() {
        didSet { persistSelection() }
    }

    private let store = ManagedSettingsStore()
    private static let selectionKey = "stopphone_blocking_selection"
    private var cancellables = Set<AnyCancellable>()
    private let speechSynthesizer = AVSpeechSynthesizer()

    init() {
        totalBlockMode = UserDefaults.standard.bool(forKey: "stopphone_total_block")
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        loadSelection()
        // Restore blocking state from UserDefaults first (survives cold launch even if
        // authorization status isn't immediately available or only .applications was set).
        // Cross-check with ManagedSettingsStore to auto-correct if settings were cleared externally.
        let savedBlocking = UserDefaults.standard.bool(forKey: "stopphone_is_blocking")
        let storeHasSettings = store.shield.applicationCategories != nil
                            || store.shield.webDomainCategories != nil
                            || store.shield.applications != nil
        isBlocking = savedBlocking || storeHasSettings
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
        // Request notification permission alongside Family Controls
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        registerNotificationCategory()
    }

    /// Registers the interactive notification category with Open / Ignore action buttons.
    /// Must be called once before any notification is delivered.
    private func registerNotificationCategory() {
        let openAction = UNNotificationAction(
            identifier: "STOPPHONE_OPEN",
            title: String(localized: "notif.action.open"),
            options: .foreground          // .foreground opens the app automatically
        )
        let ignoreAction = UNNotificationAction(
            identifier: "STOPPHONE_IGNORE",
            title: String(localized: "notif.action.ignore"),
            options: [.destructive]       // red label, no foreground — blocking stays active
        )
        let category = UNNotificationCategory(
            identifier: "STOPPHONE_DRIVING",
            actions: [openAction, ignoreAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Blocking

    func applyBlocking() {
        guard !isBlocking else { return }
        // Show overlay immediately before applying Screen Time restrictions
        blockingEpoch += 1
        isBlocking = true
        UserDefaults.standard.set(true, forKey: "stopphone_is_blocking")
        sendDrivingNotification()
        speakDrivingAlert()
        guard isAuthorized else { return }
        if totalBlockMode {
            store.shield.applicationCategories = .all(except: [])
            store.shield.webDomainCategories = .all(except: [])
        } else {
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
    }

    func removeBlocking() {
        // Always clear the ManagedSettingsStore to handle state desync
        // (e.g. app restarted after a trip, or user force-quit while blocking was active)
        if isAuthorized { store.clearAllSettings() }
        isBlocking = false
        UserDefaults.standard.set(false, forKey: "stopphone_is_blocking")
        cancelDrivingNotification()
    }

    // MARK: - Notifications

    /// Sends an immediate time-sensitive notification so the user can tap and open the overlay.
    /// iOS prevents apps from foregrounding themselves; this is the closest to automatic possible.
    private func sendDrivingNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.driving.title")
        content.body = String(localized: "notif.driving.body")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "STOPPHONE_DRIVING"   // attaches Open / Ignore buttons
        let request = UNNotificationRequest(
            identifier: "stopphone.driving",
            content: content,
            trigger: nil          // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelDrivingNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: ["stopphone.driving"])
        center.removePendingNotificationRequests(withIdentifiers: ["stopphone.driving"])
    }

    /// Speaks the driving alert aloud — routes through car Bluetooth speakers automatically
    /// when a hands-free / A2DP device is connected.
    private func speakDrivingAlert() {
        // Set audio session to playback so it works in background and routes to car speakers.
        // .duckOthers lowers music volume while speaking.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)

        let text = String(localized: "speech.driving.alert")
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let voiceLang = langCode == "fr" ? "fr-FR" : "en-US"

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLang)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Background-safe Combine observers

    /// Wire speed & Bluetooth signals into blocking decisions via Combine.
    /// Unlike SwiftUI .onChange, these subscriptions fire even when the app is
    /// backgrounded (as long as location background mode keeps the process alive).
    func observeMonitors(speed: SpeedMonitor, bluetooth: BluetoothMonitor) {
        cancellables.removeAll()

        Publishers.CombineLatest(
            Publishers.CombineLatest3(
                speed.$isAboveThreshold,
                speed.$isEnabled,
                bluetooth.$isCarConnected
            ),
            bluetooth.$bluetoothTriggerEnabled
        )
        .sink { [weak self] combined, btEnabled in
            let (isAbove, isEnabled, btConnected) = combined
            let shouldBlock = (btEnabled && btConnected) || (isAbove && isEnabled)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if shouldBlock {
                    self.applyBlocking()
                } else {
                    self.removeBlocking()
                }
            }
        }
        .store(in: &cancellables)
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
