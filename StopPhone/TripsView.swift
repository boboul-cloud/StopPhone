import MapKit
import SwiftUI

struct TripsView: View {

    @EnvironmentObject private var tripStore: TripStore
    @EnvironmentObject private var vehicleStore: VehicleStore
    @State private var showClearConfirm = false
    @State private var vehicleFilter: UUID? = nil   // nil = all

    var body: some View {
        NavigationStack {
            Group {
                if tripStore.trips.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(String(localized: "trips.title"))
            .toolbar {
                if !tripStore.trips.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog(
                String(localized: "trips.clear.confirm"),
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "trips.clear.yes"), role: .destructive) {
                    tripStore.clearAll()
                }
                Button(String(localized: "overlay.disable.confirm.no"), role: .cancel) {}
            }
        }
    }

    private var filteredTrips: [Trip] {
        guard let id = vehicleFilter else { return tripStore.trips }
        return tripStore.trips.filter { $0.vehicleID == id }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🛣️").font(.system(size: 64))
            Text(String(localized: "trips.empty.title"))
                .font(.headline)
            Text(String(localized: "trips.empty.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            // Stats
            Section {
                StatsRow(
                    icon: "🛣️",
                    label: String(localized: "trips.stats.count"),
                    value: "\(tripStore.totalTrips)"
                )
                StatsRow(
                    icon: "⏱️",
                    label: String(localized: "trips.stats.duration"),
                    value: formatTotalDuration(tripStore.totalDurationSeconds)
                )
                StatsRow(
                    icon: "📏",
                    label: String(localized: "trips.stats.distance"),
                    value: formatDistance(tripStore.totalDistanceMeters)
                )
                StatsRow(
                    icon: "💨",
                    label: String(localized: "trips.stats.maxspeed"),
                    value: String(format: "%.0f km/h", tripStore.maxSpeedAllTime)
                )
            } header: {
                Text(String(localized: "trips.stats.header"))
            }

            // Vehicle filter chips
            if !vehicleStore.vehicles.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                emoji: "🌐",
                                title: String(localized: "trips.filter.all"),
                                isSelected: vehicleFilter == nil,
                                tint: .accentColor
                            ) { vehicleFilter = nil }
                            ForEach(vehicleStore.vehicles) { v in
                                FilterChip(
                                    emoji: v.emoji,
                                    title: v.name,
                                    isSelected: vehicleFilter == v.id,
                                    tint: v.color
                                ) { vehicleFilter = v.id }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                } header: {
                    Text(String(localized: "trips.filter.header"))
                }
            }

            // Trips
            Section {
                ForEach(filteredTrips) { trip in
                    NavigationLink {
                        TripDetailView(trip: trip)
                    } label: {
                        TripRow(
                            trip: trip,
                            vehicle: vehicleStore.vehicle(withID: trip.vehicleID)
                        )
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { filteredTrips[$0] }.forEach(tripStore.delete)
                }
            } header: {
                Text(String(localized: "trips.history.header"))
            }
        }
    }

    private func formatTotalDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)min" }
        return "\(minutes)min"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}

// MARK: - Row pieces

private struct StatsRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(icon)
            Text(label)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FilterChip: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? tint.opacity(0.25) : Color.gray.opacity(0.12))
            .foregroundStyle(isSelected ? tint : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? tint : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct TripRow: View {
    let trip: Trip
    let vehicle: Vehicle?

    var body: some View {
        HStack(spacing: 12) {
            Text(vehicle?.emoji ?? trip.trigger.emoji)
                .font(.title2)
                .frame(width: 38, height: 38)
                .background((vehicle?.color ?? .orange).opacity(0.18))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vehicle?.name ?? String(localized: "trips.vehicle.unknown"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if vehicle == nil {
                        Text(trip.trigger.emoji).font(.caption)
                    }
                }
                Text(trip.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label(durationString, systemImage: "clock")
                    Text("•").foregroundStyle(.tertiary)
                    Label(distanceString, systemImage: "ruler")
                    Text("•").foregroundStyle(.tertiary)
                    Label(String(format: "%.0f km/h", trip.maxSpeedKmh), systemImage: "speedometer")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var durationString: String {
        let total = Int(trip.duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)min" }
        if m > 0 { return "\(m)min" }
        return "\(s)s"
    }

    private var distanceString: String {
        if trip.distanceMeters >= 1000 {
            return String(format: "%.1f km", trip.distanceMeters / 1000)
        }
        return String(format: "%.0f m", trip.distanceMeters)
    }
}

// MARK: - Trip detail with map

struct TripDetailView: View {

    let trip: Trip
    @EnvironmentObject private var tripStore: TripStore
    @EnvironmentObject private var vehicleStore: VehicleStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                mapView
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)

                vehicleCard
                statsCard
            }
            .padding(.vertical)
        }
        .navigationTitle(trip.startDate.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var mapView: some View {
        let coords = trip.route.map(\.coordinate)
        if coords.count >= 2 {
            Map(initialPosition: .region(region(for: coords))) {
                MapPolyline(coordinates: coords)
                    .stroke(vehicleStore.vehicle(withID: trip.vehicleID)?.color ?? .orange,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                if let first = coords.first {
                    Marker(String(localized: "trip.start"), systemImage: "flag.fill",
                           coordinate: first)
                        .tint(.green)
                }
                if let last = coords.last {
                    Marker(String(localized: "trip.end"), systemImage: "flag.checkered",
                           coordinate: last)
                        .tint(.red)
                }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.gray.opacity(0.12))
                VStack(spacing: 8) {
                    Text("🗺️").font(.system(size: 48))
                    Text(String(localized: "trip.noroute"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var vehicleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "trip.vehicle.header"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Menu {
                Button {
                    tripStore.assignVehicle(nil, to: trip.id)
                } label: {
                    Label(String(localized: "trip.vehicle.none"), systemImage: "questionmark.circle")
                }
                ForEach(vehicleStore.vehicles) { v in
                    Button {
                        tripStore.assignVehicle(v.id, to: trip.id)
                    } label: {
                        Label("\(v.emoji) \(v.name)", systemImage: "car.fill")
                    }
                }
            } label: {
                let v = vehicleStore.vehicle(withID: trip.vehicleID)
                HStack(spacing: 12) {
                    Text(v?.emoji ?? "❓")
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background((v?.color ?? .gray).opacity(0.18))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v?.name ?? String(localized: "trips.vehicle.unknown"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(String(localized: "trip.vehicle.tap"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var statsCard: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "clock", label: String(localized: "trip.duration"),
                      value: durationString)
            Divider().padding(.leading, 44)
            DetailRow(icon: "ruler", label: String(localized: "trip.distance"),
                      value: distanceString)
            Divider().padding(.leading, 44)
            DetailRow(icon: "speedometer", label: String(localized: "trip.maxspeed"),
                      value: String(format: "%.0f km/h", trip.maxSpeedKmh))
            Divider().padding(.leading, 44)
            DetailRow(icon: "gauge.with.dots.needle.50percent",
                      label: String(localized: "trip.avgspeed"),
                      value: String(format: "%.0f km/h", trip.avgSpeedKmh))
            Divider().padding(.leading, 44)
            DetailRow(icon: triggerIcon(trip.trigger),
                      label: String(localized: "trip.trigger"),
                      value: triggerLabel(trip.trigger))
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func region(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return MKCoordinateRegion()
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private var durationString: String {
        let total = Int(trip.duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)min" }
        if m > 0 { return "\(m)min \(s)s" }
        return "\(s)s"
    }

    private var distanceString: String {
        if trip.distanceMeters >= 1000 {
            return String(format: "%.2f km", trip.distanceMeters / 1000)
        }
        return String(format: "%.0f m", trip.distanceMeters)
    }

    private func triggerIcon(_ t: Trip.Trigger) -> String {
        switch t {
        case .speed:     return "speedometer"
        case .bluetooth: return "car.fill"
        case .demo:      return "testtube.2"
        }
    }

    private func triggerLabel(_ t: Trip.Trigger) -> String {
        switch t {
        case .speed:     return String(localized: "trip.trigger.speed")
        case .bluetooth: return String(localized: "trip.trigger.bluetooth")
        case .demo:      return String(localized: "trip.trigger.demo")
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(label)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
