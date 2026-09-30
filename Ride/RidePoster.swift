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
    }

    static func jpeg(_ stats: Stats) async -> URL? {
        let size = CGSize(width: canvasWidth, height: canvasHeight)
        let map = await mapImage(track: stats.track, size: size)
        let image = render(stats, map: map)
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

    private static func render(_ stats: Stats, map: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvasWidth, height: canvasHeight),
            format: format
        )
        return renderer.image { context in
            map.draw(in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
            drawScrim(in: context.cgContext)
            drawStats(stats)
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
        let textWidth = canvasWidth - sideInset * 2
        let columnWidth = textWidth / 2
        let distanceX = canvasWidth - sideInset - columnWidth
        let timeX = sideInset

        if let icon = UIImage(systemName: stats.kind.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 58, weight: .medium))?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            icon.draw(in: CGRect(x: canvasWidth - sideInset - 72, y: 1040, width: 72, height: 58))
        }

        draw(stats.kind.posterTitle(at: stats.date), in: CGRect(x: sideInset, y: 1136, width: textWidth, height: 80), font: .systemFont(ofSize: 64, weight: .bold), color: .white, alignment: .right)

        let labelFont = UIFont.systemFont(ofSize: 32, weight: .regular)
        let labelColor = UIColor.white.withAlphaComponent(0.92)
        let numberFont = UIFont.systemFont(ofSize: 68, weight: .bold)
        draw("מרחק", in: CGRect(x: distanceX, y: 1268, width: columnWidth, height: 42), font: labelFont, color: labelColor, alignment: .right)
        draw("זמן", in: CGRect(x: timeX, y: 1268, width: columnWidth, height: 42), font: labelFont, color: labelColor, alignment: .right)
        draw(distanceText(stats.distanceMeters), in: CGRect(x: distanceX, y: 1318, width: columnWidth, height: 84), font: numberFont, color: .white, alignment: .right)

        let time = timeParts(stats.movingSeconds)
        draw(time.primary, in: CGRect(x: timeX, y: 1318, width: columnWidth, height: 84), font: numberFont, color: .white, alignment: .right)
        if let secondary = time.secondary {
            draw(secondary, in: CGRect(x: timeX, y: 1408, width: columnWidth, height: 84), font: numberFont, color: .white, alignment: .right)
        }

        draw("עלייה", in: CGRect(x: sideInset, y: 1568, width: textWidth, height: 42), font: labelFont, color: labelColor, alignment: .right)
        draw(ascentText(stats.ascentMeters), in: CGRect(x: sideInset, y: 1616, width: textWidth, height: 84), font: numberFont, color: .white, alignment: .right)
        draw(speedLine(stats), in: CGRect(x: sideInset, y: 1736, width: textWidth, height: 48), font: .systemFont(ofSize: 32, weight: .semibold), color: .white, alignment: .right)
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = .rightToLeft
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func distanceText(_ meters: Double) -> String {
        String(format: "%.2f ק״מ", meters / 1000)
    }

    private static func ascentText(_ meters: Double) -> String {
        "\(Int(meters.rounded())) מ׳"
    }

    private static func timeParts(_ seconds: TimeInterval) -> (primary: String, secondary: String?) {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
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
        var latitudeDelta = Swift.max((maxLat - minLat) * 1.28, 0.008)
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

func presentRideShare(url: URL) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
        return
    }
    var presenter = root
    while let presented = presenter.presentedViewController {
        presenter = presented
    }
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
    }
    presenter.present(controller, animated: true)
}
