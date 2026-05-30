import FamilyControls
import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var speedMonitor: SpeedMonitor
    @EnvironmentObject private var blockingManager: BlockingManager
    @EnvironmentObject private var bluetoothMonitor: BluetoothMonitor
    @EnvironmentObject private var vehicleStore: VehicleStore
    @State private var showPicker = false

    @AppStorage(UDKey.parentPIN) private var savedPIN: String = ""
    @State private var showPINSetup = false
    @State private var showPINPromptForChange = false
    @State private var showPINPromptForRemove = false

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
                        NavigationLink {
                            VehiclesView()
                        } label: {
                            HStack {
                                Label(String(localized: "settings.vehicles.manage"),
                                      systemImage: "car.2.fill")
                                Spacer()
                                Text("\(vehicleStore.vehicles.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let current = bluetoothMonitor.currentBluetoothDeviceName {
                            HStack(spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(.green)
                                Text(current)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                if let v = vehicleStore.matchingVehicle(for: current) {
                                    Text("\(v.emoji) \(v.name)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(v.color)
                                } else {
                                    Text(String(localized: "settings.bluetooth.unmatched"))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
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
                            : (vehicleStore.vehicles.isEmpty
                                ? String(localized: "settings.bluetooth.footer.any")
                                : String(localized: "settings.bluetooth.footer.vehicles"))
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

                if let err = blockingManager.authorizationError {
                    Section {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }

                // MARK: Calls warning
                Section {
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
                    .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "calls.title"))
                }

                // MARK: Demo
                Section {
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
                    .padding(.vertical, 2)

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
                    .buttonStyle(.plain)
                } header: {
                    Text("Demo")
                }

                // MARK: Voice alert
                Section {
                    Toggle(isOn: $blockingManager.voiceAlertEnabled) {
                        Label(String(localized: "settings.voice.toggle"),
                              systemImage: "speaker.wave.2.fill")
                    }
                    .tint(.purple)
                } header: {
                    Text(String(localized: "settings.section.voice"))
                } footer: {
                    Text(String(localized: "settings.voice.footer"))
                }

                // MARK: Passenger mode
                Section {
                    if blockingManager.isPassengerActive,
                       let until = blockingManager.passengerSnoozeUntil {
                        HStack {
                            Label(
                                String(format: String(localized: "settings.passenger.active"),
                                       until.formatted(date: .omitted, time: .shortened)),
                                systemImage: "person.fill"
                            )
                            .foregroundStyle(.blue)
                            Spacer()
                        }
                        Button(role: .destructive) {
                            blockingManager.cancelPassengerMode()
                        } label: {
                            Label(String(localized: "settings.passenger.cancel"),
                                  systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            blockingManager.enablePassengerMode()
                        } label: {
                            Label(String(localized: "settings.passenger.enable"),
                                  systemImage: "person.crop.circle.badge.checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.section.passenger"))
                } footer: {
                    Text(String(localized: "settings.passenger.footer"))
                }

                // MARK: Auto-disable
                Section {
                    Picker(
                        selection: $speedMonitor.autoDisableMinutes
                    ) {
                        ForEach(AppConstants.autoDisableOptions, id: \.self) { value in
                            if value == 0 {
                                Text(String(localized: "settings.autodisable.off")).tag(0)
                            } else {
                                Text(String(format: String(localized: "settings.autodisable.minutes"), value))
                                    .tag(value)
                            }
                        }
                    } label: {
                        Label(String(localized: "settings.autodisable.label"),
                              systemImage: "timer")
                    }
                } header: {
                    Text(String(localized: "settings.section.autodisable"))
                } footer: {
                    Text(String(localized: "settings.autodisable.footer"))
                }

                // MARK: Parental PIN
                Section {
                    if savedPIN.count == 4 {
                        Button {
                            // Require existing PIN before allowing change
                            showPINPromptForChange = true
                        } label: {
                            Label(String(localized: "settings.pin.change"),
                                  systemImage: "lock.rotation")
                        }
                        Button(role: .destructive) {
                            showPINPromptForRemove = true
                        } label: {
                            Label(String(localized: "settings.pin.remove"),
                                  systemImage: "lock.slash")
                        }
                    } else {
                        Button {
                            showPINSetup = true
                        } label: {
                            Label(String(localized: "settings.pin.set"),
                                  systemImage: "lock.shield")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text(String(localized: "settings.section.pin"))
                } footer: {
                    Text(String(localized: "settings.pin.footer"))
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
            .sheet(isPresented: $showPINSetup) {
                PINSetupView()
            }
            .sheet(isPresented: $showPINPromptForChange) {
                PINPromptView(
                    onSuccess: {
                        showPINPromptForChange = false
                        // Defer until sheet animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showPINSetup = true
                        }
                    },
                    onCancel: { showPINPromptForChange = false }
                )
            }
            .sheet(isPresented: $showPINPromptForRemove) {
                PINPromptView(
                    onSuccess: {
                        savedPIN = ""
                        showPINPromptForRemove = false
                    },
                    onCancel: { showPINPromptForRemove = false }
                )
            }
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
