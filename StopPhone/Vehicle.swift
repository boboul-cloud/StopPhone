import Foundation
import SwiftUI

/// A vehicle the user owns, identified by its Bluetooth audio device name.
struct Vehicle: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String                  // "Voiture de Robert"
    var emoji: String                 // 🚗 🚙 🛻 🏍️ 🚐 …
    var bluetoothDeviceName: String?  // exact substring match against the BT port name
    var colorHex: String              // "#FF6A00"
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🚗",
        bluetoothDeviceName: String? = nil,
        colorHex: String = "#FF8A00",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.bluetoothDeviceName = bluetoothDeviceName
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var color: Color { Color(hex: colorHex) ?? .orange }

    /// True if the connected Bluetooth `portName` matches this vehicle.
    func matches(bluetoothName: String?) -> Bool {
        guard let bt = bluetoothDeviceName, !bt.isEmpty,
              let portName = bluetoothName, !portName.isEmpty else { return false }
        return portName.localizedCaseInsensitiveContains(bt)
            || bt.localizedCaseInsensitiveContains(portName)
    }
}

/// Stores and persists the user's vehicles.
@MainActor
final class VehicleStore: ObservableObject {

    @Published private(set) var vehicles: [Vehicle] = []

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ vehicle: Vehicle) {
        vehicles.append(vehicle)
        save()
    }

    func update(_ vehicle: Vehicle) {
        guard let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[idx] = vehicle
        save()
    }

    func delete(_ vehicle: Vehicle) {
        vehicles.removeAll { $0.id == vehicle.id }
        save()
    }

    func vehicle(withID id: UUID?) -> Vehicle? {
        guard let id else { return nil }
        return vehicles.first { $0.id == id }
    }

    /// First vehicle whose BT name matches the connected port name.
    func matchingVehicle(for bluetoothName: String?) -> Vehicle? {
        guard let name = bluetoothName, !name.isEmpty else { return nil }
        return vehicles.first { $0.matches(bluetoothName: name) }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: UDKey.vehicles),
              let decoded = try? JSONDecoder().decode([Vehicle].self, from: data)
        else {
            migrateLegacyDeviceIfNeeded()
            return
        }
        vehicles = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(vehicles) else { return }
        UserDefaults.standard.set(data, forKey: UDKey.vehicles)
    }

    /// One-time migration: if a user already pinned a BT device under the legacy
    /// single-device key, turn it into a Vehicle so they keep their setup.
    private func migrateLegacyDeviceIfNeeded() {
        guard let legacy = UserDefaults.standard.string(forKey: UDKey.btDevice),
              !legacy.isEmpty else { return }
        let v = Vehicle(
            name: legacy,
            emoji: "🚗",
            bluetoothDeviceName: legacy
        )
        vehicles = [v]
        save()
    }
}

// MARK: - Color hex helper

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

/// Curated palette of emoji + colors to pick when creating a vehicle.
enum VehiclePalette {
    static let emojis: [String] = [
        "🚗", "🚙", "🚐", "🛻", "🚚", "🏎️", "🏍️", "🛵", "🚌", "🚛", "🚓", "🚑", "🚕", "🚲"
    ]
    static let colors: [String] = [
        "#FF6A00", "#FF3B30", "#FF2D55", "#AF52DE", "#5856D6",
        "#007AFF", "#34C759", "#30B0C7", "#FFCC00", "#8E8E93"
    ]
}
