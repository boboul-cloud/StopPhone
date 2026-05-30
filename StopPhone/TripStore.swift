import Foundation
import Combine
import CoreLocation

/// A point recorded along a trip's GPS trace.
struct RoutePoint: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    /// Speed at this sample (km/h, 0 if unknown).
    let speedKmh: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A single recorded driving session.
struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    let startDate: Date
    var endDate: Date
    var maxSpeedKmh: Double
    var avgSpeedKmh: Double
    /// What triggered the trip start.
    let trigger: Trigger
    /// Vehicle associated with this trip (matched via Bluetooth at trip start).
    var vehicleID: UUID?
    /// Total driving distance in meters.
    var distanceMeters: Double
    /// Sampled GPS trace (sparse — one point per `gpsDistanceFilter` meters).
    var route: [RoutePoint]

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
    var distanceKm: Double { distanceMeters / 1000.0 }

    // MARK: - Backward-compatible Codable
    // Old trips persisted before v2 don't have vehicleID / distanceMeters / route.

    enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, maxSpeedKmh, avgSpeedKmh, trigger
        case vehicleID, distanceMeters, route
    }

    init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        maxSpeedKmh: Double,
        avgSpeedKmh: Double,
        trigger: Trigger,
        vehicleID: UUID? = nil,
        distanceMeters: Double = 0,
        route: [RoutePoint] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.maxSpeedKmh = maxSpeedKmh
        self.avgSpeedKmh = avgSpeedKmh
        self.trigger = trigger
        self.vehicleID = vehicleID
        self.distanceMeters = distanceMeters
        self.route = route
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        maxSpeedKmh = try c.decode(Double.self, forKey: .maxSpeedKmh)
        avgSpeedKmh = try c.decode(Double.self, forKey: .avgSpeedKmh)
        trigger = try c.decode(Trigger.self, forKey: .trigger)
        vehicleID = try c.decodeIfPresent(UUID.self, forKey: .vehicleID)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? 0
        route = try c.decodeIfPresent([RoutePoint].self, forKey: .route) ?? []
    }
}

/// Persists driving history and exposes a published list for the UI.
@MainActor
final class TripStore: ObservableObject {

    @Published private(set) var trips: [Trip] = []

    private static let maxStoredTrips = 200
    /// Cap on stored route points per trip (sliding window).
    private static let maxRoutePointsPerTrip = 2000

    // In-progress trip aggregation
    private var openTripID: UUID?
    private var openStart: Date?
    private var openTrigger: Trip.Trigger = .speed
    private var openVehicleID: UUID?
    private var openMaxSpeed: Double = 0
    private var speedSum: Double = 0
    private var speedSamples: Int = 0
    private var openDistance: Double = 0
    private var openRoute: [RoutePoint] = []
    private var lastSampleLocation: CLLocation?

    init() {
        load()
    }

    // MARK: - Recording API

    func beginTrip(trigger: Trip.Trigger, vehicleID: UUID? = nil) {
        guard openTripID == nil else { return }
        openTripID = UUID()
        openStart = Date()
        openTrigger = trigger
        openVehicleID = vehicleID
        openMaxSpeed = 0
        speedSum = 0
        speedSamples = 0
        openDistance = 0
        openRoute = []
        lastSampleLocation = nil
    }

    /// Set the vehicle mid-trip if it wasn't known at start.
    func setVehicle(_ id: UUID?) {
        guard openTripID != nil else { return }
        openVehicleID = id
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

    /// Record a GPS location during an open trip — accumulates distance and stores a route point.
    func record(location: CLLocation, speedKmh: Double) {
        guard openTripID != nil else { return }
        // Reject low-accuracy fixes so distance doesn't drift.
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy < 50 else { return }
        if let last = lastSampleLocation {
            let delta = location.distance(from: last)
            if delta >= 5 {
                openDistance += delta
                appendRoutePoint(location: location, speedKmh: speedKmh)
                lastSampleLocation = location
            }
        } else {
            appendRoutePoint(location: location, speedKmh: speedKmh)
            lastSampleLocation = location
        }
    }

    private func appendRoutePoint(location: CLLocation, speedKmh: Double) {
        let point = RoutePoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            speedKmh: speedKmh
        )
        openRoute.append(point)
        if openRoute.count > Self.maxRoutePointsPerTrip {
            openRoute.removeFirst(openRoute.count - Self.maxRoutePointsPerTrip)
        }
    }

    func endTrip() {
        guard let id = openTripID, let start = openStart else { return }
        defer { resetOpen() }
        let end = Date()
        let duration = end.timeIntervalSince(start)
        guard duration >= AppConstants.minTripDuration else { return }
        let avg = speedSamples > 0 ? speedSum / Double(speedSamples) : 0
        let trip = Trip(
            id: id,
            startDate: start,
            endDate: end,
            maxSpeedKmh: openMaxSpeed,
            avgSpeedKmh: avg,
            trigger: openTrigger,
            vehicleID: openVehicleID,
            distanceMeters: openDistance,
            route: openRoute
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
        openVehicleID = nil
        openMaxSpeed = 0
        speedSum = 0
        speedSamples = 0
        openDistance = 0
        openRoute = []
        lastSampleLocation = nil
    }

    // MARK: - Stats

    var totalTrips: Int { trips.count }
    var totalDurationSeconds: TimeInterval { trips.reduce(0) { $0 + $1.duration } }
    var maxSpeedAllTime: Double { trips.map(\.maxSpeedKmh).max() ?? 0 }
    var totalDistanceMeters: Double { trips.reduce(0) { $0 + $1.distanceMeters } }

    func trips(forVehicle id: UUID) -> [Trip] {
        trips.filter { $0.vehicleID == id }
    }

    // MARK: - Mutations

    func delete(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        save()
    }

    func clearAll() {
        trips.removeAll()
        save()
    }

    /// Re-assign a vehicle to an existing trip.
    func assignVehicle(_ vehicleID: UUID?, to tripID: UUID) {
        guard let idx = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[idx].vehicleID = vehicleID
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
