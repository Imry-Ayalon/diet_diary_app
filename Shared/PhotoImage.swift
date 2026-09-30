import UIKit
import ImageIO

nonisolated enum PhotoImage {
    static func jpeg(_ image: UIImage, maxSide: CGFloat = 1024, quality: CGFloat = 0.5) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let ratio = min(1, maxSide / max(longest, 1))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: quality)
    }

    static func jpeg(_ data: Data, maxSide: CGFloat, quality: CGFloat) -> Data? {
        guard let image = cgImage(data, maxPixel: maxSide) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: quality)
    }

    static func thumbnail(_ data: Data, points: CGFloat) -> UIImage? {
        guard let image = cgImage(data, maxPixel: points * 3) else { return nil }
        return UIImage(cgImage: image)
    }

    static func cgImage(_ data: Data, maxPixel: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel.rounded(.up)),
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

func presentShare(url: URL) {
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
