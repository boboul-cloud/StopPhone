import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var speedMonitor: SpeedMonitor
    @EnvironmentObject private var blockingManager: BlockingManager

    var body: some View {
        TabView {
            dashboardTab
                .tabItem { Label(String(localized: "tab.dashboard"), systemImage: "speedometer") }
            SettingsView()
                .tabItem { Label(String(localized: "tab.settings"), systemImage: "gear") }
        }
        .task {
            if speedMonitor.authorizationStatus == .notDetermined {
                speedMonitor.requestPermission()
            }
            if !blockingManager.isAuthorized {
                await blockingManager.requestAuthorization()
            }
        }
        .onChange(of: speedMonitor.isAboveThreshold) { _, isAbove in
            guard speedMonitor.isEnabled else { return }
            if isAbove {
                blockingManager.applyBlocking()
            } else {
                blockingManager.removeBlocking()
            }
        }
        .onChange(of: speedMonitor.isEnabled) { _, isEnabled in
            if !isEnabled { blockingManager.removeBlocking() }
        }
    }

    private var dashboardTab: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        enableToggleCard
                        speedCard
                        blockingStatusCard
                        callsWarningCard
                        if !blockingManager.isAuthorized {
                            permissionCard
                        }
                        if let err = blockingManager.authorizationError {
                            errorCard(err)
                        }
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


    // MARK: - Background

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Enable Toggle Card

    private var enableToggleCard: some View {
        HStack(spacing: 14) {
            Text("🛡️")
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 2) {
                Text(speedMonitor.isEnabled
                     ? String(localized: "status.enabled")
                     : String(localized: "status.disabled"))
                    .font(.headline)
                Text(String(localized: "toggle.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { speedMonitor.isEnabled },
                set: { speedMonitor.setEnabled($0) }
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

    // MARK: - Blocking Status Card

    private var blockingStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                blockingManager.isBlocking
                    ? String(localized: "blocking.active")
                    : String(localized: "blocking.inactive"),
                systemImage: blockingManager.isBlocking ? "shield.fill" : "shield"
            )
            .font(.headline)
            .foregroundStyle(blockingManager.isBlocking ? .red : .secondary)

            Divider()

            BlockingRow(
                emoji: "📱",
                title: String(localized: "block.social"),
                subtitle: "Instagram, TikTok, Snapchat, X…",
                isBlocked: blockingManager.isBlocking
            )

            BlockingRow(
                emoji: "🎬",
                title: String(localized: "block.entertainment"),
                subtitle: "YouTube, Netflix, jeux…",
                isBlocked: blockingManager.isBlocking
            )

            BlockingRow(
                emoji: "🌐",
                title: String(localized: "block.web"),
                subtitle: "Sites réseaux sociaux dans Safari",
                isBlocked: blockingManager.isBlocking
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
                    openFocusSettings()
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
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Permission Card

    private var permissionCard: some View {
        Button {
            Task { await blockingManager.requestAuthorization() }
        } label: {
            HStack(spacing: 14) {
                Text("🔐")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "permission.title"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(localized: "permission.body"))
                        .font(.caption)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

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

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private func openFocusSettings() {
        // Opens the Settings app; there is no direct URL for Focus mode on iOS.
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
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
            Image(systemName: isBlocked ? "xmark.shield.fill" : "checkmark.circle")
                .foregroundStyle(isBlocked ? .red : .green)
                .font(.title3)
        }
    }
}
