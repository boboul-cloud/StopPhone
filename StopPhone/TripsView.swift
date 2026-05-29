import SwiftUI

struct TripsView: View {

    @EnvironmentObject private var tripStore: TripStore
    @State private var showClearConfirm = false

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
                    icon: "💨",
                    label: String(localized: "trips.stats.maxspeed"),
                    value: String(format: "%.0f km/h", tripStore.maxSpeedAllTime)
                )
            } header: {
                Text(String(localized: "trips.stats.header"))
            }

            Section {
                ForEach(tripStore.trips) { trip in
                    TripRow(trip: trip)
                }
                .onDelete { indexSet in
                    indexSet.map { tripStore.trips[$0] }.forEach(tripStore.delete)
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
}

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

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Text(trip.trigger.emoji)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Color.orange.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Label(durationString, systemImage: "clock")
                        .font(.caption)
                    Text("•").font(.caption).foregroundStyle(.tertiary)
                    Label(String(format: "%.0f km/h", trip.maxSpeedKmh), systemImage: "speedometer")
                        .font(.caption)
                }
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
}
