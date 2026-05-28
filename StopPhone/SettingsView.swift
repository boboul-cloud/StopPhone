import FamilyControls
import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var speedMonitor: SpeedMonitor
    @EnvironmentObject private var blockingManager: BlockingManager
    @EnvironmentObject private var bluetoothMonitor: BluetoothMonitor
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
                    Slider(
                        value: $speedMonitor.speedThreshold,
                        in: 5...120,
                        step: 5
                    ) {
                        Text(String(localized: "settings.speed"))
                    } minimumValueLabel: {
                        Text("5").font(.caption).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("120").font(.caption).foregroundStyle(.secondary)
                    }
                    .tint(.orange)
                } header: {
                    Text(String(localized: "settings.section.detection"))
                } footer: {
                    Text(String(localized: "settings.section.detection.footer"))
                }

                // MARK: Bluetooth vehicle trigger
                Section {
                    Toggle(isOn: $bluetoothMonitor.bluetoothTriggerEnabled) {
                        Label(String(localized: "settings.bluetooth.trigger"),
                              systemImage: "car.fill")
                    }
                    .tint(.blue)

                    if bluetoothMonitor.bluetoothTriggerEnabled {
                        if let target = bluetoothMonitor.targetDeviceName, !target.isEmpty {
                            HStack {
                                Label(target, systemImage: "bluetooth")
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    bluetoothMonitor.clearTargetDevice()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Label(String(localized: "settings.bluetooth.device.any"),
                                  systemImage: "bluetooth")
                                .foregroundStyle(.secondary)
                        }

                        if let current = bluetoothMonitor.currentBluetoothDeviceName {
                            Button {
                                bluetoothMonitor.learnCurrentDevice()
                            } label: {
                                Label(
                                    String(format: String(localized: "settings.bluetooth.learn"),
                                           current),
                                    systemImage: "checkmark.circle"
                                )
                            }
                            .foregroundStyle(.blue)
                        } else {
                            Label(String(localized: "settings.bluetooth.none"),
                                  systemImage: "bluetooth")
                                .foregroundStyle(.tertiary)
                                .font(.footnote)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.section.bluetooth"))
                } footer: {
                    Text(
                        !bluetoothMonitor.bluetoothTriggerEnabled
                            ? String(localized: "settings.bluetooth.footer.off")
                            : (bluetoothMonitor.targetDeviceName != nil
                                ? String(localized: "settings.bluetooth.footer.specific")
                                : String(localized: "settings.bluetooth.footer.any"))
                    )
                }

                // MARK: Shortcuts guide
                Section {
                    ShortcutStepRow(number: "1", text: String(localized: "shortcuts.step1"))
                    ShortcutStepRow(number: "2", text: String(localized: "shortcuts.step2"))
                    ShortcutStepRow(number: "3", text: String(localized: "shortcuts.step3"))
                    ShortcutStepRow(number: "4", text: String(localized: "shortcuts.step4"))
                    Button {
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(String(localized: "shortcuts.open"), systemImage: "arrow.up.forward.app")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text(String(localized: "settings.section.shortcuts"))
                } footer: {
                    Text(String(localized: "settings.section.shortcuts.footer"))
                }

                // MARK: Total block
                Section {
                    Toggle(isOn: $blockingManager.totalBlockMode) {
                        Label(String(localized: "settings.total.block"), systemImage: "lock.fill")
                    }
                    .tint(.red)
                } header: {
                    Text(String(localized: "settings.section.total.block"))
                } footer: {
                    Text(blockingManager.totalBlockMode
                         ? String(localized: "settings.total.block.footer.on")
                         : String(localized: "settings.total.block.footer.off"))
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

                // MARK: Alerts info
                Section {
                    InfoRow(icon: "📵",
                            title: String(localized: "block.overlay"),
                            detail: String(localized: "block.overlay.sub"))
                } header: {
                    Text(String(localized: "settings.section.alerts"))
                }

                if let err = blockingManager.authorizationError {
                    Section {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }

                // MARK: About
                Section {
                    // App identity row
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [Color(red: 1, green: 0.23, blue: 0.19),
                                         Color(red: 1, green: 0.42, blue: 0.21)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                            .overlay(Text("🛡️").font(.system(size: 26)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("StopPhone")
                                .font(.headline)
                            Text(String(format: "%@ %@ (%@)",
                                        String(localized: "about.version"),
                                        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                                        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)

                    // Developer
                    HStack {
                        Label(String(localized: "about.developer"), systemImage: "person.fill")
                        Spacer()
                        Text(String(localized: "about.developer.name"))
                            .foregroundStyle(.secondary)
                    }

                    // Website
                    Link(destination: URL(string: "https://boboul-cloud.github.io/StopPhone")!) {
                        Label(String(localized: "about.website"), systemImage: "globe")
                    }

                    // Privacy Policy
                    Link(destination: URL(string: "https://boboul-cloud.github.io/StopPhone/privacy.html")!) {
                        Label(String(localized: "about.privacy"), systemImage: "lock.shield")
                    }

                    // Terms & Conditions
                    Link(destination: URL(string: "https://boboul-cloud.github.io/StopPhone/terms.html")!) {
                        Label(String(localized: "about.terms"), systemImage: "doc.text")
                    }
                } header: {
                    Text(String(localized: "about.section"))
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .familyActivityPicker(
                isPresented: $showPicker,
                selection: $blockingManager.activitySelection
            )
        }
    }

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

private struct ShortcutStepRow: View {
    let number: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }
}
