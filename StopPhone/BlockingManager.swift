import AVFoundation
import Combine
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Manages driving protection:
///  1. Screen Time blocking via FamilyControls + ManagedSettings
///  2. Fullscreen overlay in-app (handled by ContentView)
///  3. Local notification (debounced)
///  4. Voice alert via AVSpeechSynthesizer (plays through car Bluetooth)
///  5. Passenger mode (temporary snooze) + trip history recording
@MainActor
final class BlockingManager: ObservableObject {

    @Published var isAuthorized: Bool = false
    @Published var isBlocking: Bool = false
    @Published var authorizationError: String?
    @Published var totalBlockMode: Bool {
        didSet { UserDefaults.standard.set(totalBlockMode, forKey: UDKey.totalBlock) }
    }
    @Published var voiceAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceAlertEnabled, forKey: UDKey.voiceAlertEnabled) }
    }
    /// Epoch incremented every time blocking is (re)applied — drives overlay reappearance.
    @Published var blockingEpoch: Int = 0
    @Published var activitySelection: FamilyActivitySelection = FamilyActivitySelection() {
        didSet { persistSelection() }
    }
    /// Passenger snooze: blocking is bypassed until this date (nil = no snooze).
    @Published var passengerSnoozeUntil: Date? {
        didSet {
            if let d = passengerSnoozeUntil {
                UserDefaults.standard.set(d.timeIntervalSince1970, forKey: UDKey.passengerUntil)
            } else {
                UserDefaults.standard.removeObject(forKey: UDKey.passengerUntil)
            }
        }
    }

    private let store = ManagedSettingsStore()
    private var cancellables = Set<AnyCancellable>()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastNotificationDate: Date?
    private var snoozeTimer: Timer?

    // Trip recording — assigned by the App after init.
    weak var tripStore: TripStore?

    init() {
        totalBlockMode    = UserDefaults.standard.bool(forKey: UDKey.totalBlock)
        voiceAlertEnabled = UserDefaults.standard.object(forKey: UDKey.voiceAlertEnabled) as? Bool ?? true
        isAuthorized      = AuthorizationCenter.shared.authorizationStatus == .approved
        loadSelection()
        // Restore passenger snooze (drop if expired)
        let ts = UserDefaults.standard.double(forKey: UDKey.passengerUntil)
        if ts > 0 {
            let d = Date(timeIntervalSince1970: ts)
            if d > Date() {
                passengerSnoozeUntil = d
                scheduleSnoozeExpiry(at: d)
            } else {
                UserDefaults.standard.removeObject(forKey: UDKey.passengerUntil)
            }
        }
        // Restore last blocking state.
        let savedBlocking = UserDefaults.standard.bool(forKey: UDKey.isBlocking)
        let storeHasSettings = store.shield.applicationCategories != nil
                            || store.shield.webDomainCategories != nil
                            || store.shield.applications != nil
        isBlocking = savedBlocking || storeHasSettings
        // Stale-cleanup: persisted flag without real settings => desync, drop it.
        if isBlocking && !storeHasSettings {
            isBlocking = false
            UserDefaults.standard.set(false, forKey: UDKey.isBlocking)
        }

        // One-time AVAudioSession setup (was previously re-applied on each blocking).
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
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
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        registerNotificationCategory()
    }

    private func registerNotificationCategory() {
        let openAction = UNNotificationAction(
            identifier: "STOPPHONE_OPEN",
            title: String(localized: "notif.action.open"),
            options: .foreground
        )
        let ignoreAction = UNNotificationAction(
            identifier: "STOPPHONE_IGNORE",
            title: String(localized: "notif.action.ignore"),
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "STOPPHONE_DRIVING",
            actions: [openAction, ignoreAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Passenger mode

    func enablePassengerMode(duration: TimeInterval = AppConstants.passengerSnoozeDuration) {
        let end = Date().addingTimeInterval(duration)
        passengerSnoozeUntil = end
        scheduleSnoozeExpiry(at: end)
        if isBlocking { removeBlocking(recordTrip: false) }
    }

    func cancelPassengerMode() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        passengerSnoozeUntil = nil
    }

    var isPassengerActive: Bool {
        if let d = passengerSnoozeUntil { return d > Date() }
        return false
    }

    private func scheduleSnoozeExpiry(at date: Date) {
        snoozeTimer?.invalidate()
        let interval = max(date.timeIntervalSinceNow, 0)
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.passengerSnoozeUntil = nil }
        }
    }

    // MARK: - Blocking

    func applyBlocking(trigger: Trip.Trigger = .speed) {
        if isPassengerActive { return }
        guard !isBlocking else { return }
        blockingEpoch += 1
        isBlocking = true
        UserDefaults.standard.set(true, forKey: UDKey.isBlocking)
        tripStore?.beginTrip(trigger: trigger)
        sendDrivingNotification()
        if voiceAlertEnabled { speakDrivingAlert() }
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

    func removeBlocking(recordTrip: Bool = true) {
        if isAuthorized { store.clearAllSettings() }
        isBlocking = false
        UserDefaults.standard.set(false, forKey: UDKey.isBlocking)
        cancelDrivingNotification()
        if recordTrip { tripStore?.endTrip() }
    }

    /// Called by SpeedMonitor on each GPS update so the open trip records max/avg.
    func sampleSpeed(_ kmh: Double) {
        guard isBlocking else { return }
        tripStore?.record(speed: kmh)
    }

    // MARK: - Notifications

    private func sendDrivingNotification() {
        if let last = lastNotificationDate,
           Date().timeIntervalSince(last) < AppConstants.notificationCooldown {
            return
        }
        lastNotificationDate = Date()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.driving.title")
        content.body = String(localized: "notif.driving.body")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "STOPPHONE_DRIVING"
        let request = UNNotificationRequest(
            identifier: "stopphone.driving",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelDrivingNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: ["stopphone.driving"])
        center.removePendingNotificationRequests(withIdentifiers: ["stopphone.driving"])
    }

    private func speakDrivingAlert() {
        try? AVAudioSession.sharedInstance().setActive(true)
        let text = String(localized: "speech.driving.alert")
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let voiceLang = langCode == "fr" ? "fr-FR" : "en-US"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLang)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Combine observers

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
            let speedTriggered = isAbove && isEnabled
            let btTriggered    = btEnabled && btConnected
            let shouldBlock    = speedTriggered || btTriggered
            Task { @MainActor [weak self] in
                guard let self else { return }
                if shouldBlock {
                    let t: Trip.Trigger
                    if speedTriggered && speed.isDemoMode { t = .demo }
                    else if speedTriggered { t = .speed }
                    else { t = .bluetooth }
                    self.applyBlocking(trigger: t)
                } else {
                    self.removeBlocking()
                }
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Persistence

    private func persistSelection() {
        do {
            let data = try JSONEncoder().encode(activitySelection)
            UserDefaults.standard.set(data, forKey: UDKey.blockingSelection)
        } catch {
            print("[StopPhone] Failed to encode activity selection: \(error)")
        }
    }

    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: UDKey.blockingSelection),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        activitySelection = decoded
    }
}
