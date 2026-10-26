import UIKit
import MapKit

@MainActor
enum RidePoster {
    struct Stats {
        var kind: ActivityKind
        var date: Date
        var distanceMeters: Double
        var movingSeconds: TimeInterval
        var ascentMeters: Double
        var maxSpeedMetersPerSecond: Double
        var track: [TrackPoint]
        var language: MovementLanguage = .hebrew
    }

    static func jpeg(_ stats: Stats, backgroundPhoto: UIImage? = nil) async -> URL? {
        let size = CGSize(width: canvasWidth, height: canvasHeight)
        let background: UIImage
        if let backgroundPhoto {
            background = fittedPhoto(backgroundPhoto, size: size)
        } else {
            background = await mapImage(track: stats.track, size: size)
        }
        let image = render(stats, background: background)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let url = FileManager.default.temporaryDirectory.appending(path: "ride-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static let canvasWidth: CGFloat = 1080
    private static let canvasHeight: CGFloat = 1920
    private static let sideInset: CGFloat = 64

    private static func render(_ stats: Stats, background: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasWidth, height: canvasHeight),
            format: format
        )
        return renderer.image { context in
            background.draw(in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
            drawScrim(in: context.cgContext)
            drawStats(stats)
        }
    }

    private static func fittedPhoto(_ photo: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let photoSize = photo.size
            guard photoSize.width > 0, photoSize.height > 0 else {
                UIColor.darkGray.setFill()
                UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
                return
            }
            let scale = max(size.width / photoSize.width, size.height / photoSize.height)
            let drawn = CGSize(width: photoSize.width * scale, height: photoSize.height * scale)
            let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
            photo.draw(in: CGRect(origin: origin, size: drawn))
        }
    }

    private static func drawScrim(in context: CGContext) {
        let colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.18).cgColor,
            UIColor.black.withAlphaComponent(0.62).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.38, 0.58, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: canvasHeight),
            options: []
        )
    }

    private static func drawStats(_ stats: Stats) {
        let language = stats.language
        let rtl = language == .hebrew
        let textWidth = canvasWidth - sideInset * 2
        let columnWidth = textWidth / 2
        let alignment: NSTextAlignment = rtl ? .right : .left
        let distanceX = rtl ? canvasWidth - sideInset - columnWidth : sideInset + columnWidth
        let timeX = rtl ? sideInset : sideInset
        let iconX = rtl ? canvasWidth - sideInset - 72 : sideInset

        if let icon = UIImage(systemName: stats.kind.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 58, weight: .medium))?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            icon.draw(in: CGRect(x: iconX, y: 1040, width: 72, height: 58))
        }

        draw(
            stats.kind.posterTitle(at: stats.date, language: language),
            in: CGRect(x: sideInset, y: 1136, width: textWidth, height: 80),
            font: .systemFont(ofSize: 64, weight: .bold),
            color: .white,
            alignment: alignment,
            rtl: rtl
        )

        let labelFont = UIFont.systemFont(ofSize: 32, weight: .regular)
        let labelColor = UIColor.white.withAlphaComponent(0.92)
        let numberFont = UIFont.systemFont(ofSize: 68, weight: .bold)
        let distanceLabel = MovementText.t("מרחק", "Distance", language)
        let timeLabel = MovementText.t("זמן", "Time", language)
        let ascentLabel = MovementText.t("עלייה", "Ascent", language)

        draw(distanceLabel, in: CGRect(x: distanceX, y: 1268, width: columnWidth, height: 42), font: labelFont, color: labelColor, alignment: alignment, rtl: rtl)
        draw(timeLabel, in: CGRect(x: timeX, y: 1268, width: columnWidth, height: 42), font: labelFont, color: labelColor, alignment: alignment, rtl: rtl)
        draw(distanceText(stats.distanceMeters, language: language), in: CGRect(x: distanceX, y: 1318, width: columnWidth, height: 84), font: numberFont, color: .white, alignment: alignment, rtl: rtl)

        let time = timeParts(stats.movingSeconds, language: language)
        draw(time.primary, in: CGRect(x: timeX, y: 1318, width: columnWidth, height: 84), font: numberFont, color: .white, alignment: alignment, rtl: rtl)
        if let secondary = time.secondary {
            draw(secondary, in: CGRect(x: timeX, y: 1408, width: columnWidth, height: 84), font: numberFont, color: .white, alignment: alignment, rtl: rtl)
        }

        draw(ascentLabel, in: CGRect(x: sideInset, y: 1568, width: textWidth, height: 42), font: labelFont, color: labelColor, alignment: alignment, rtl: rtl)
        draw(ascentText(stats.ascentMeters, language: language), in: CGRect(x: sideInset, y: 1616, width: textWidth, height: 84), font: numberFont, color: .white, alignment: alignment, rtl: rtl)
        draw(speedLine(stats), in: CGRect(x: sideInset, y: 1736, width: textWidth, height: 48), font: .systemFont(ofSize: 32, weight: .semibold), color: .white, alignment: alignment, rtl: rtl)
    }

    private static func draw(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment,
        rtl: Bool
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func distanceText(_ meters: Double, language: MovementLanguage) -> String {
        language == .english
            ? String(format: "%.2f km", meters / 1000)
            : String(format: "%.2f ק״מ", meters / 1000)
    }

    private static func ascentText(_ meters: Double, language: MovementLanguage) -> String {
        language == .english
            ? "\(Int(meters.rounded())) m"
            : "\(Int(meters.rounded())) מ׳"
    }

    private static func timeParts(_ seconds: TimeInterval, language: MovementLanguage) -> (primary: String, secondary: String?) {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        if language == .english {
            if hours > 0 {
                return ("\(hours) hr", "\(minutes) min")
            }
            return ("\(minutes) min", "\(remainder) sec")
        }
        if hours > 0 {
            return ("\(hours) שע׳", "\(minutes) דק׳")
        }
        return ("\(minutes) דק׳", "\(remainder) שנ׳")
    }

    private static func speedLine(_ stats: Stats) -> String {
        let average = RideSummary.averageKilometersPerHour(
            distanceMeters: stats.distanceMeters,
            movingSeconds: stats.movingSeconds
        )
        if stats.language == .english {
            var line = String(format: "Avg %.1f km/h", average)
            if stats.maxSpeedMetersPerSecond > 0 {
                line += String(format: "  ·  Max %.1f", stats.maxSpeedMetersPerSecond * 3.6)
            }
            return line
        }
        var line = String(format: "ממוצע %.1f קמ״ש", average)
        if stats.maxSpeedMetersPerSecond > 0 {
            line += String(format: "  ·  מרבי %.1f", stats.maxSpeedMetersPerSecond * 3.6)
        }
        return line
    }

    private static func mapImage(track: [TrackPoint], size: CGSize) async -> UIImage {
        let shown = thinned(track)
        if let region = shareRegion(for: shown), let snapshot = await takeSnapshot(region: region, size: size) {
            let points = shown.map { snapshot.point(for: $0.coordinate) }
            return drawRoute(points, on: snapshot.image, size: size)
        }
        return drawRoute(normalized(shown, in: size), on: nil, size: size)
    }

    private static func shareRegion(for track: [TrackPoint]) -> MKCoordinateRegion? {
        guard let first = track.first else { return nil }
        let latitudes = track.map(\.latitude)
        let longitudes = track.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latitudeDelta = Swift.max((maxLat - minLat) * 1.28, 0.008)
        var longitudeDelta = Swift.max((maxLon - minLon) * 1.7, 0.008)
        let metersPerDegree = 111_320.0
        let metersPerLongitude = metersPerDegree * cos(center.latitude * .pi / 180)
        let imageAspect = canvasWidth / canvasHeight
        let regionAspect = (longitudeDelta * metersPerLongitude) / (latitudeDelta * metersPerDegree)
        if regionAspect < imageAspect * 1.35 {
            longitudeDelta = latitudeDelta * metersPerDegree * imageAspect * 1.35 / Swift.max(metersPerLongitude, 1)
        }
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private static func takeSnapshot(region: MKCoordinateRegion, size: CGSize) async -> MKMapSnapshotter.Snapshot? {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = 1
        let snapshotter = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                continuation.resume(returning: snapshot)
            }
        }
    }

    private static func drawRoute(_ points: [CGPoint], on base: UIImage?, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            if let base {
                base.draw(in: CGRect(origin: .zero, size: size))
            } else {
                UIColor(red: 0.90, green: 0.94, blue: 0.93, alpha: 1).setFill()
                UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            }
            guard points.count > 1 else { return }
            let path = UIBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            UIColor(red: 0.72, green: 0.22, blue: 0.05, alpha: 0.45).setStroke()
            path.lineWidth = 14
            path.stroke()
            UIColor(red: 0.98, green: 0.40, blue: 0.16, alpha: 1).setStroke()
            path.lineWidth = 8
            path.stroke()
        }
    }

    private static func normalized(_ track: [TrackPoint], in size: CGSize) -> [CGPoint] {
        guard let region = shareRegion(for: track) else { return [] }
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        let latSpan = max(maxLat - minLat, 0.0001)
        let lonSpan = max(maxLon - minLon, 0.0001)
        let inset: CGFloat = 48
        return track.map { point in
            let x = inset + (point.longitude - minLon) / lonSpan * (size.width - inset * 2)
            let y = inset + (maxLat - point.latitude) / latSpan * (size.height - inset * 2)
            return CGPoint(x: x, y: y)
        }
    }

    private static func thinned(_ track: [TrackPoint]) -> [TrackPoint] {
        guard track.count > 1200 else { return track }
        let step = Int((Double(track.count) / 1200).rounded(.up))
        var points = stride(from: 0, to: track.count, by: step).map { track[$0] }
        if let last = track.last, points.last != last {
            points.append(last)
        }
        return points
    }
}
