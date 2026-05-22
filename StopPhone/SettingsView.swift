import FamilyControls
import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var speedMonitor: SpeedMonitor
    @EnvironmentObject private var blockingManager: BlockingManager
    @State private var showPicker = false

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

                // MARK: App blocking
                Section {
                    if blockingManager.isAuthorized {
                        Button {
                            showPicker = true
                        } label: {
                            HStack {
                                Label(String(localized: "settings.choose.apps"),
                                      systemImage: "apps.iphone")
                                Spacer()
                                Text(selectionSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)

                        if !activitySelectionIsEmpty {
                            Button(role: .destructive) {
                                blockingManager.activitySelection = FamilyActivitySelection()
                            } label: {
                                Label(String(localized: "settings.reset"),
                                      systemImage: "arrow.counterclockwise")
                            }
                        }
                    } else {
                        Button {
                            Task { await blockingManager.requestAuthorization() }
                        } label: {
                            Label(String(localized: "permission.title"),
                                  systemImage: "hand.raised.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.section.blocking"))
                } footer: {
                    Text(activitySelectionIsEmpty
                         ? String(localized: "settings.section.footer.default")
                         : String(localized: "settings.section.footer.custom"))
                }

                // MARK: Alerts
                Section {
                    InfoRow(icon: "📵",
                            title: String(localized: "block.overlay"),
                            detail: String(localized: "block.overlay.sub"))
                    InfoRow(icon: "🔔",
                            title: String(localized: "block.notif"),
                            detail: String(localized: "block.notif.sub"))
                } header: {
                    Text(String(localized: "settings.section.alerts"))
                }

                // MARK: Permissions
                if blockingManager.isAuthorized && !blockingManager.notificationsAuthorized {
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

                // MARK: Error
                if let err = blockingManager.authorizationError {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .familyActivityPicker(
                isPresented: $showPicker,
                selection: $blockingManager.activitySelection
            )
        }
    }

    // MARK: - Helpers

    private var activitySelectionIsEmpty: Bool {
        blockingManager.activitySelection.categoryTokens.isEmpty
        && blockingManager.activitySelection.applicationTokens.isEmpty
    }

    private var selectionSummary: String {
        let cats = blockingManager.activitySelection.categoryTokens.count
        let apps = blockingManager.activitySelection.applicationTokens.count
        if cats == 0 && apps == 0 { return String(localized: "settings.default") }
        var parts: [String] = []
        if cats > 0 { parts.append("\(cats) catégorie\(cats > 1 ? "s" : "")") }
        if apps > 0 { parts.append("\(apps) app\(apps > 1 ? "s" : "")") }
        return parts.joined(separator: ", ")
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
