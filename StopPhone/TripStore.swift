import Foundation
import Combine

/// A single recorded driving session.
struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    let startDate: Date
    var endDate: Date
    var maxSpeedKmh: Double
    var avgSpeedKmh: Double
    /// What triggered the trip start.
    let trigger: Trigger

    enum Trigger: String, Codable {
        case speed
        case bluetooth
        case demo

        var emoji: String {
            switch self {
            case .speed: return "🏎️"
            case .bluetooth: return "🚗"
            case .demo: return "🧪"
            }
        }
    }

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

/// Persists driving history and exposes a published list for the UI.
@MainActor
final class TripStore: ObservableObject {

    @Published private(set) var trips: [Trip] = []

    private static let maxStoredTrips = 200

    // In-progress trip aggregation
    private var openTripID: UUID?
    private var openStart: Date?
    private var openTrigger: Trip.Trigger = .speed
    private var openMaxSpeed: Double = 0
    private var speedSum: Double = 0
    private var speedSamples: Int = 0

    init() {
        load()
    }

    // MARK: - Recording API

    func beginTrip(trigger: Trip.Trigger) {
        guard openTripID == nil else { return }
        openTripID = UUID()
        openStart = Date()
        openTrigger = trigger
        openMaxSpeed = 0
        speedSum = 0
        speedSamples = 0
    }

    /// Record a speed sample (km/h) during an open trip.
    func record(speed kmh: Double) {
        guard openTripID != nil else { return }
        if kmh > openMaxSpeed { openMaxSpeed = kmh }
        if kmh > 0 {
            speedSum += kmh
            speedSamples += 1
        }
    }

    func endTrip() {
        guard let id = openTripID, let start = openStart else { return }
        defer { resetOpen() }
        let end = Date()
        let duration = end.timeIntervalSince(start)
        // Filter out phantom trips (BT glitch, demo toggles, …)
        guard duration >= AppConstants.minTripDuration else { return }
        let avg = speedSamples > 0 ? speedSum / Double(speedSamples) : 0
        let trip = Trip(
            id: id,
            startDate: start,
            endDate: end,
            maxSpeedKmh: openMaxSpeed,
            avgSpeedKmh: avg,
            trigger: openTrigger
        )
        trips.insert(trip, at: 0)
        if trips.count > Self.maxStoredTrips {
            trips = Array(trips.prefix(Self.maxStoredTrips))
        }
        save()
    }

    private func resetOpen() {
        openTripID = nil
        openStart = nil
        openMaxSpeed = 0
        speedSum = 0
        speedSamples = 0
    }

    // MARK: - Stats

    var totalTrips: Int { trips.count }
    var totalDurationSeconds: TimeInterval { trips.reduce(0) { $0 + $1.duration } }
    var maxSpeedAllTime: Double { trips.map(\.maxSpeedKmh).max() ?? 0 }

    // MARK: - Mutations

    func delete(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        save()
    }

    func clearAll() {
        trips.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: UDKey.trips),
              let decoded = try? JSONDecoder().decode([Trip].self, from: data)
        else { return }
        trips = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(trips) else { return }
        UserDefaults.standard.set(data, forKey: UDKey.trips)
    }
}
