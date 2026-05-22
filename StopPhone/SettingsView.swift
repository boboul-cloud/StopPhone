import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var speedMonitor: SpeedMonitor
    @EnvironmentObject private var blockingManager: BlockingManager

    var body: some View {
        NavigationStack {
            List {

                // MARK: Detection
                Section {
                    HStack {
                        Label(String(localized: "settings.speed"), systemImage: "speedometer")
                        Spacer()
                        Text(String(format: "%.0f km/h", speedMonitor.speedThreshold))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "settings.section.detection"))
                } footer: {
                    Text(String(localized: "settings.section.detection.footer"))
                }

                // MARK: Blocking
                Section {
                    InfoRow(icon: "📵",
                            title: String(localized: "block.overlay"),
                            detail: String(localized: "block.overlay.sub"))
                    InfoRow(icon: "🔔",
                            title: String(localized: "block.notif"),
                            detail: String(localized: "block.notif.sub"))
                } header: {
                    Text(String(localized: "settings.section.blocking"))
                } footer: {
                    Text(String(localized: "settings.section.footer.default"))
                }

                // MARK: Notifications permission
                if !blockingManager.notificationsAuthorized {
                    Section {
                        Button {
                            Task { await blockingManager.requestNotificationAuthorization() }
                        } label: {
                            Label(String(localized: "settings.notif.allow"),
                                  systemImage: "bell.badge")
                                .foregroundStyle(.blue)
                        }
                    } header: {
                        Text(String(localized: "settings.section.permissions"))
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title"))
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
