import Foundation
import MapKit
import UIKit

/// Generates a multi-page PDF from a list of trips (one page per trip).
/// Each page contains an orange header, a map snapshot with the GPS route,
/// and a stats card (duration, distance, speed, estimated cost).
@MainActor
enum TripPDFExporter {

    // MARK: - Public

    static func export(
        trips: [Trip],
        vehicles: [Vehicle],
        fuelPricePerLiter: Double
    ) async -> URL {
        let page   = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 points
        let margin: CGFloat = 32
        let mapH:   CGFloat = 260

        // 1. Fetch all map snapshots concurrently (sequentially is fine here, short trips)
        var snapshots: [UUID: UIImage] = [:]
        for trip in trips where trip.route.count >= 2 {
            if let img = await mapSnapshot(for: trip,
                                           width: page.width - margin * 2,
                                           height: mapH) {
                snapshots[trip.id] = img
            }
        }

        // 2. Render PDF
        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            for trip in trips {
                ctx.beginPage()
                drawPage(trip: trip,
                         vehicle: vehicles.first { $0.id == trip.vehicleID },
                         mapImage: snapshots[trip.id],
                         fuelPricePerLiter: fuelPricePerLiter,
                         ctx: ctx,
                         page: page,
                         margin: margin,
                         mapH: mapH)
            }
        }

        // 3. Persist to temp dir
        let fileName = "trips_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return url
    }

    // MARK: - Map snapshot

    private static func mapSnapshot(for trip: Trip,
                                    width: CGFloat,
                                    height: CGFloat) async -> UIImage? {
        let coords = trip.route.map(\.coordinate)
        guard coords.count >= 2 else { return nil }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let opts        = MKMapSnapshotter.Options()
        opts.region     = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.005),
                                   longitudeDelta: max((maxLon - minLon) * 1.5, 0.005))
        )
        opts.size       = CGSize(width: width, height: height)
        opts.scale      = UIScreen.main.scale
        opts.mapType    = .standard

        return await withCheckedContinuation { continuation in
            MKMapSnapshotter(options: opts).start { snap, error in
                guard let snap, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                // Overlay route polyline + start/end markers
                let rendered = UIGraphicsImageRenderer(size: snap.image.size).image { _ in
                    snap.image.draw(at: .zero)

                    let path = UIBezierPath()
                    for (i, coord) in coords.enumerated() {
                        let pt = snap.point(for: coord)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    UIColor.systemOrange.setStroke()
                    path.lineWidth   = 3.5
                    path.lineCapStyle  = .round
                    path.lineJoinStyle = .round
                    path.stroke()

                    marker(at: snap.point(for: coords.first!), color: .systemGreen)
                    marker(at: snap.point(for: coords.last!),  color: .systemRed)
                }
                continuation.resume(returning: rendered)
            }
        }
    }

    private static func marker(at pt: CGPoint, color: UIColor) {
        let r: CGFloat = 7
        let circle = UIBezierPath(ovalIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                  width: r * 2, height: r * 2))
        color.setFill();         circle.fill()
        UIColor.white.setStroke(); circle.lineWidth = 2; circle.stroke()
    }

    // MARK: - Page drawing

    private static func drawPage(trip: Trip,
                                  vehicle: Vehicle?,
                                  mapImage: UIImage?,
                                  fuelPricePerLiter: Double,
                                  ctx: UIGraphicsPDFRendererContext,
                                  page: CGRect,
                                  margin: CGFloat,
                                  mapH: CGFloat) {
        let pageW    = page.width
        let contentW = pageW - margin * 2
        var y: CGFloat

        // ── Orange header ──────────────────────────────────────────────────────
        let headerH: CGFloat = 64
        UIColor.systemOrange.withAlphaComponent(0.9).setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: headerH)).fill()

        let emoji = vehicle?.emoji ?? trip.trigger.emoji
        (emoji as NSString).draw(
            at: CGPoint(x: margin, y: 12),
            withAttributes: [.font: UIFont.systemFont(ofSize: 30)]
        )

        let vName = vehicle?.name ?? NSLocalizedString("trips.vehicle.unknown", comment: "")
        (vName as NSString).draw(
            at: CGPoint(x: margin + 46, y: 10),
            withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18),
                             .foregroundColor: UIColor.white]
        )

        let dateStr = trip.startDate.formatted(date: .long, time: .shortened)
        (dateStr as NSString).draw(
            at: CGPoint(x: margin + 46, y: 34),
            withAttributes: [.font: UIFont.systemFont(ofSize: 12),
                             .foregroundColor: UIColor.white.withAlphaComponent(0.85)]
        )

        y = headerH + 16

        // ── Map ───────────────────────────────────────────────────────────────
        let mapRect = CGRect(x: margin, y: y, width: contentW, height: mapH)
        let mapPath = UIBezierPath(roundedRect: mapRect, cornerRadius: 10)
        ctx.cgContext.saveGState()
        mapPath.addClip()
        if let img = mapImage {
            img.draw(in: mapRect)
        } else {
            UIColor.systemGray6.setFill()
            UIBezierPath(roundedRect: mapRect, cornerRadius: 10).fill()
            let noRoute = NSLocalizedString("trip.noroute", comment: "")
            ("🗺️  \(noRoute)" as NSString).draw(
                at: CGPoint(x: margin + 16, y: y + mapH / 2 - 10),
                withAttributes: [.font: UIFont.systemFont(ofSize: 14),
                                 .foregroundColor: UIColor.secondaryLabel]
            )
        }
        ctx.cgContext.restoreGState()
        UIColor.lightGray.withAlphaComponent(0.45).setStroke()
        mapPath.lineWidth = 0.5; mapPath.stroke()

        y += mapH + 20

        // ── Section title ─────────────────────────────────────────────────────
        let sectionTitle = NSLocalizedString("trips.stats.header", comment: "").uppercased()
        (sectionTitle as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                             .foregroundColor: UIColor.secondaryLabel]
        )
        y += 18

        // ── Stats rows ────────────────────────────────────────────────────────
        let totalSec = Int(trip.duration)
        let h = totalSec / 3600, m = (totalSec % 3600) / 60, s = totalSec % 60
        let durStr  = h > 0 ? "\(h)h \(m)min" : (m > 0 ? "\(m)min \(s)s" : "\(s)s")
        let distStr = trip.distanceKm >= 1
            ? String(format: "%.2f km", trip.distanceKm)
            : String(format: "%.0f m",  trip.distanceMeters)

        var rows: [(icon: String, label: String, value: String)] = [
            ("⏱️", NSLocalizedString("trip.duration",  comment: ""), durStr),
            ("📏", NSLocalizedString("trip.distance",  comment: ""), distStr),
            ("💨", NSLocalizedString("trip.maxspeed",  comment: ""), String(format: "%.0f km/h", trip.maxSpeedKmh)),
            ("📊", NSLocalizedString("trip.avgspeed",  comment: ""), String(format: "%.0f km/h", trip.avgSpeedKmh)),
        ]
        if let v = vehicle, let conso = v.fuelConsumptionL100km, fuelPricePerLiter > 0 {
            let cost = trip.distanceKm / 100.0 * conso * fuelPricePerLiter
            rows.append(("⛽", NSLocalizedString("trip.cost", comment: ""),
                         String(format: "%.2f €", cost)))
        }

        let rowH:   CGFloat = 30
        let cardH            = CGFloat(rows.count) * rowH + 14
        let cardRect         = CGRect(x: margin, y: y, width: contentW, height: cardH)
        UIColor.systemGray6.setFill()
        UIBezierPath(roundedRect: cardRect, cornerRadius: 10).fill()

        y += 8
        for (i, row) in rows.enumerated() {
            let rowY = y + CGFloat(i) * rowH
            if i > 0 {
                UIColor.separator.withAlphaComponent(0.35).setStroke()
                let sep = UIBezierPath()
                sep.move(to: CGPoint(x: margin + 12, y: rowY))
                sep.addLine(to: CGPoint(x: margin + contentW - 12, y: rowY))
                sep.lineWidth = 0.5; sep.stroke()
            }
            // Icon + label
            ("\(row.icon)  \(row.label)" as NSString).draw(
                at: CGPoint(x: margin + 12, y: rowY + 7),
                withAttributes: [.font: UIFont.systemFont(ofSize: 13),
                                 .foregroundColor: UIColor.label]
            )
            // Value right-aligned
            let valAttr = NSAttributedString(
                string: row.value,
                attributes: [.font: UIFont.boldSystemFont(ofSize: 13),
                             .foregroundColor: UIColor.label]
            )
            let valW = valAttr.size().width
            valAttr.draw(at: CGPoint(x: margin + contentW - 12 - valW, y: rowY + 7))
        }
    }
}
