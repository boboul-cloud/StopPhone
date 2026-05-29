import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var speedMonitor: SpeedMonitor
    @EnvironmentObject private var blockingManager: BlockingManager
    @EnvironmentObject private var bluetoothMonitor: BluetoothMonitor
    @EnvironmentObject private var tripStore: TripStore

    @AppStorage(UDKey.parentPIN) private var savedPIN: String = ""
    @State private var showInitializing = true
    @State private var showPINPrompt = false
    @State private var pinPendingAction: (() -> Void)?

    var body: some View {
        ZStack {
            TabView {
                dashboardTab
                    .tabItem { Label(String(localized: "tab.dashboard"), systemImage: "speedometer") }
                TripsView()
                    .tabItem { Label(String(localized: "tab.trips"), systemImage: "map") }
                SettingsView()
                    .tabItem { Label(String(localized: "tab.settings"), systemImage: "gear") }
            }

            // Fullscreen driving overlay
            if blockingManager.isBlocking {
                DrivingOverlay(onRequestDisable: requestProtectionDisable)
                    .id(blockingManager.blockingEpoch)
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }

            // Loading veil at startup while permissions resolve
            if showInitializing {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                    Text(String(localized: "loading.title"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            // PIN prompt sheet (visual)
            if showPINPrompt {
                Color.black.opacity(0.5).ignoresSafeArea()
                    .transition(.opacity)
                PINPromptView(
                    onSuccess: {
                        let action = pinPendingAction
                        pinPendingAction = nil
                        showPINPrompt = false
                        action?()
                    },
                    onCancel: {
                        pinPendingAction = nil
                        showPINPrompt = false
                    }
                )
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding()
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showPINPrompt)
        .task {
            if speedMonitor.authorizationStatus == .notDetermined {
                speedMonitor.requestPermission()
            }
            await blockingManager.requestAuthorization()
            blockingManager.observeMonitors(speed: speedMonitor, bluetooth: bluetoothMonitor)
            withAnimation(.easeOut(duration: 0.35)) { showInitializing = false }
        }
    }

    /// Wraps a destructive action with the parental PIN if one is set.
    func requestProtectionDisable(_ action: @escaping () -> Void) {
        if savedPIN.count == 4 {
            pinPendingAction = action
            showPINPrompt = true
        } else {
            action()
        }
    }

    // MARK: - Dashboard Tab

    private var dashboardTab: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if blockingManager.isPassengerActive { passengerBanner }
                        enableToggleCard
                        speedCard
                        statusCard
                        locationPermissionCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(String(localized: "app.title"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Enable Toggle Card

    private var enableToggleCard: some View {
        HStack(spacing: 14) {
            Text(speedMonitor.isEnabled ? "🛡️" : "💤")
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 2) {
                Text(speedMonitor.isEnabled
                     ? String(localized: "status.enabled")
                     : String(localized: "status.disabled"))
                    .font(.headline)
                Text(String(format: String(localized: "toggle.subtitle"), Int(speedMonitor.speedThreshold)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { speedMonitor.isEnabled },
                set: { newValue in
                    if newValue {
                        speedMonitor.setEnabled(true)
                    } else {
                        // Disabling is destructive → wrap with PIN if configured
                        requestProtectionDisable {
                            speedMonitor.setEnabled(false)
                        }
                    }
                }
            ))
            .labelsHidden()
            .tint(.green)
            .scaleEffect(1.2)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Speed Card

    private var speedCard: some View {
        VStack(spacing: 10) {
            if speedMonitor.isDemoMode {
                Text(String(localized: "demo.badge"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            Text(speedEmoji)
                .font(.system(size: 52))
                .animation(.spring(duration: 0.4), value: speedEmoji)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", speedMonitor.currentSpeedKmh))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(speedColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: speedMonitor.currentSpeedKmh)
                Text("km/h")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            Text(speedStatusLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(speedColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(speedColor.opacity(0.15))
                .clipShape(Capsule())

            Text(String(format: String(localized: "threshold.label"), Int(speedMonitor.speedThreshold)))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(speedColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                blockingManager.isBlocking
                    ? String(localized: "blocking.active")
                    : String(localized: "blocking.inactive"),
                systemImage: blockingManager.isBlocking ? "exclamationmark.shield.fill" : "shield"
            )
            .font(.headline)
            .foregroundStyle(blockingManager.isBlocking ? .red : .secondary)

            Divider()

            if blockingManager.isAuthorized {
                let hasCustom = !blockingManager.activitySelection.categoryTokens.isEmpty
                                || !blockingManager.activitySelection.applicationTokens.isEmpty
                BlockingRow(
                    emoji: blockingManager.totalBlockMode ? "🔒" : "📵",
                    title: blockingManager.totalBlockMode
                        ? String(localized: "block.screentime.total")
                        : (hasCustom
                            ? String(localized: "block.screentime.custom")
                            : String(localized: "block.screentime.all")),
                    subtitle: blockingManager.totalBlockMode
                        ? String(localized: "block.screentime.total.sub")
                        : (hasCustom
                            ? String(format: String(localized: "block.screentime.custom.sub"),
                                     blockingManager.activitySelection.categoryTokens.count
                                     + blockingManager.activitySelection.applicationTokens.count)
                            : String(localized: "block.screentime.all.sub")),
                    isBlocked: blockingManager.isBlocking
                )
            } else {
                BlockingRow(emoji: "📵",
                            title: String(localized: "block.overlay"),
                            subtitle: String(localized: "block.overlay.sub"),
                            isBlocked: blockingManager.isBlocking)
            }

            BlockingRow(emoji: "🔔",
                        title: String(localized: "block.notif"),
                        subtitle: String(localized: "block.notif.sub"),
                        isBlocked: blockingManager.isBlocking)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Demo Card

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("🧪")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(String(localized: "demo.title"))
                            .font(.subheadline.weight(.semibold))
                        Text("DEMO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    Text(String(localized: "demo.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                if speedMonitor.isDemoMode {
                    speedMonitor.stopDemo()
                } else {
                    speedMonitor.startDemo()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: speedMonitor.isDemoMode ? "stop.fill" : "play.fill")
                    Text(speedMonitor.isDemoMode
                         ? String(localized: "demo.stop")
                         : String(format: String(localized: "demo.start"), Int(speedMonitor.demoSpeedKmh)))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(speedMonitor.isDemoMode ? Color.red : Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color.orange.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Calls Warning Card

    private var callsWarningCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("⚠️")
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "calls.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(String(localized: "calls.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(String(localized: "calls.focus.button")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Passenger banner

    private var passengerBanner: some View {
        HStack(spacing: 12) {
            Text("🧍").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "passenger.banner"), passengerRemainingString))
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button {
                blockingManager.cancelPassengerMode()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var passengerRemainingString: String {
        guard let until = blockingManager.passengerSnoozeUntil else { return "" }
        let s = max(Int(until.timeIntervalSinceNow), 0)
        let m = s / 60
        return m > 0 ? "\(m) min" : "\(s) s"
    }

    // MARK: - Location Permission Card

    private var locationPermissionCard: some View {
        Group {
            if speedMonitor.authorizationStatus == .denied
                || speedMonitor.authorizationStatus == .restricted {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Text("📍")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "location.denied.title"))
                                .font(.subheadline.weight(.semibold))
                            Text(String(localized: "location.denied.body"))
                                .font(.caption)
                                .opacity(0.85)
                        }
                        Spacer()
                        Image(systemName: "gear")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    // MARK: - Helpers

    private var speedEmoji: String {
        guard speedMonitor.isEnabled else { return "🚗" }
        if speedMonitor.isAboveThreshold { return "🚨" }
        if speedMonitor.currentSpeedKmh > 8 { return "⚡️" }
        return "✅"
    }

    private var speedColor: Color {
        guard speedMonitor.isEnabled else { return .secondary }
        if speedMonitor.isAboveThreshold { return .red }
        if speedMonitor.currentSpeedKmh > 8 { return .orange }
        return .green
    }

    private var speedStatusLabel: String {
        guard speedMonitor.isEnabled else { return String(localized: "status.disabled") }
        if speedMonitor.isAboveThreshold { return String(localized: "speed.above") }
        return String(localized: "speed.below")
    }
}

// MARK: - DrivingOverlay

struct DrivingOverlay: View {
    let onRequestDisable: (@escaping () -> Void) -> Void
    @EnvironmentObject private var speedMonitor: SpeedMonitor
    @EnvironmentObject private var blockingManager: BlockingManager
    @State private var dismissed = false
    @State private var showDisableConfirmation = false

    var body: some View {
        ZStack {
            Color.red.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("🚨")
                    .font(.system(size: 80))

                Text(String(localized: "overlay.title"))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(String(format: "%.0f km/h", speedMonitor.currentSpeedKmh))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Text(String(localized: "overlay.subtitle"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                if dismissed {
                    VStack(spacing: 16) {
                        Text(String(localized: "overlay.dismissed.hint"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        Button {
                            showDisableConfirmation = true
                        } label: {
                            Text(String(localized: "overlay.disable"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.bottom, 48)
                } else {
                    Button {
                        dismissed = true
                    } label: {
                        Text(String(localized: "overlay.dismiss"))
                            .font(.headline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .confirmationDialog(
            String(localized: "overlay.disable.confirm.title"),
            isPresented: $showDisableConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "overlay.disable.confirm.yes"), role: .destructive) {
                onRequestDisable {
                    speedMonitor.setEnabled(false)
                }
            }
            Button(String(localized: "overlay.disable.confirm.no"), role: .cancel) {}
        } message: {
            Text(String(localized: "overlay.disable.confirm.message"))
        }
        .onChange(of: speedMonitor.isAboveThreshold) { _, isAbove in
            if isAbove { dismissed = false }
        }
    }
}

// MARK: - BlockingRow

private struct BlockingRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isBlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isBlocked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isBlocked ? .red : .secondary)
                .font(.title3)
        }
    }
}
