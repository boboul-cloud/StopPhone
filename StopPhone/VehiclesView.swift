import SwiftUI

struct VehiclesView: View {

    @EnvironmentObject private var vehicleStore: VehicleStore
    @EnvironmentObject private var bluetoothMonitor: BluetoothMonitor
    @EnvironmentObject private var tripStore: TripStore

    @State private var showAdd = false
    @State private var editing: Vehicle?

    var body: some View {
        List {
            // Currently-connected Bluetooth row
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "vehicles.bt.current"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(bluetoothMonitor.currentBluetoothDeviceName
                             ?? String(localized: "vehicles.bt.none"))
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    if let name = bluetoothMonitor.currentBluetoothDeviceName,
                       vehicleStore.matchingVehicle(for: name) == nil {
                        Button {
                            var v = Vehicle(name: name, bluetoothDeviceName: name)
                            v.emoji = VehiclePalette.emojis.randomElement() ?? "🚗"
                            v.colorHex = VehiclePalette.colors.randomElement() ?? "#FF8A00"
                            vehicleStore.add(v)
                        } label: {
                            Label(String(localized: "vehicles.bt.add"),
                                  systemImage: "plus.circle.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } header: {
                Text(String(localized: "vehicles.section.bluetooth"))
            } footer: {
                Text(String(localized: "vehicles.section.bluetooth.footer"))
            }

            // Vehicles list
            Section {
                if vehicleStore.vehicles.isEmpty {
                    VStack(spacing: 8) {
                        Text("🚗").font(.system(size: 44))
                        Text(String(localized: "vehicles.empty.title"))
                            .font(.subheadline.weight(.semibold))
                        Text(String(localized: "vehicles.empty.body"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(vehicleStore.vehicles) { vehicle in
                        VehicleRow(
                            vehicle: vehicle,
                            isConnected: bluetoothMonitor.currentVehicleID == vehicle.id,
                            tripCount: tripStore.trips(forVehicle: vehicle.id).count
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editing = vehicle }
                    }
                    .onDelete { idx in
                        idx.map { vehicleStore.vehicles[$0] }.forEach(vehicleStore.delete)
                    }
                }
            } header: {
                Text(String(localized: "vehicles.section.list"))
            }
        }
        .navigationTitle(String(localized: "vehicles.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            VehicleEditView(vehicle: nil) { new in
                vehicleStore.add(new)
            }
        }
        .sheet(item: $editing) { v in
            VehicleEditView(vehicle: v) { updated in
                vehicleStore.update(updated)
            }
        }
    }
}

private struct VehicleRow: View {
    let vehicle: Vehicle
    let isConnected: Bool
    let tripCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(vehicle.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(vehicle.color.opacity(0.18))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vehicle.name)
                        .font(.subheadline.weight(.semibold))
                    if isConnected {
                        Text(String(localized: "vehicles.connected"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                if let bt = vehicle.bluetoothDeviceName, !bt.isEmpty {
                    Label(bt, systemImage: "bluetooth")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(String(localized: "vehicles.no.bt"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(String(format: String(localized: "vehicles.trips.count"), tripCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit / Add sheet

struct VehicleEditView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bluetoothMonitor: BluetoothMonitor

    let original: Vehicle?
    let onSave: (Vehicle) -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var bluetoothDeviceName: String

    init(vehicle: Vehicle?, onSave: @escaping (Vehicle) -> Void) {
        self.original = vehicle
        self.onSave = onSave
        _name = State(initialValue: vehicle?.name ?? "")
        _emoji = State(initialValue: vehicle?.emoji ?? "🚗")
        _colorHex = State(initialValue: vehicle?.colorHex ?? "#FF8A00")
        _bluetoothDeviceName = State(initialValue: vehicle?.bluetoothDeviceName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "vehicles.field.name"), text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text(String(localized: "vehicles.field.name"))
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(VehiclePalette.emojis, id: \.self) { e in
                            Text(e)
                                .font(.title)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(emoji == e
                                                  ? Color.accentColor.opacity(0.25)
                                                  : Color.gray.opacity(0.10))
                                )
                                .overlay(Circle().stroke(emoji == e ? Color.accentColor : .clear,
                                                          lineWidth: 2))
                                .onTapGesture { emoji = e }
                        }
                    }
                } header: {
                    Text(String(localized: "vehicles.field.emoji"))
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(VehiclePalette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .orange)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(colorHex == hex ? Color.primary : .clear,
                                                          lineWidth: 3))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                } header: {
                    Text(String(localized: "vehicles.field.color"))
                }

                Section {
                    TextField(String(localized: "vehicles.field.bt.placeholder"),
                              text: $bluetoothDeviceName)
                        .autocorrectionDisabled()
                    if let current = bluetoothMonitor.currentBluetoothDeviceName,
                       current != bluetoothDeviceName {
                        Button {
                            bluetoothDeviceName = current
                        } label: {
                            Label(
                                String(format: String(localized: "vehicles.field.bt.use"), current),
                                systemImage: "antenna.radiowaves.left.and.right"
                            )
                        }
                    }
                } header: {
                    Text(String(localized: "vehicles.field.bt"))
                } footer: {
                    Text(String(localized: "vehicles.field.bt.footer"))
                }
            }
            .navigationTitle(original == nil
                             ? String(localized: "vehicles.add.title")
                             : String(localized: "vehicles.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "overlay.disable.confirm.no")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "vehicles.save")) {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmedName.isEmpty else { return }
                        let bt = bluetoothDeviceName.trimmingCharacters(in: .whitespaces)
                        let new = Vehicle(
                            id: original?.id ?? UUID(),
                            name: trimmedName,
                            emoji: emoji,
                            bluetoothDeviceName: bt.isEmpty ? nil : bt,
                            colorHex: colorHex,
                            createdAt: original?.createdAt ?? Date()
                        )
                        onSave(new)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
