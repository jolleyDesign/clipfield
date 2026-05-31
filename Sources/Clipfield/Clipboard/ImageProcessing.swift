import AppKit

/// Image helpers for bounding stored image size and generating row thumbnails.
enum ImageProcessing {
    static let maxStoredDimension: CGFloat = 4096
    static let thumbnailDimension: CGFloat = 96

    /// Returns the original PNG if within the dimension cap, otherwise a
    /// downscaled PNG. Keeps the stored display image from being enormous.
    static func cappedPNG(from data: Data) -> Data {
        guard let image = NSImage(data: data) else { return data }
        let size = image.size
        guard max(size.width, size.height) > maxStoredDimension else { return data }
        return downscaledPNG(image, maxDimension: maxStoredDimension) ?? data
    }

    /// A small PNG thumbnail for fast list rendering.
    static func thumbnail(from data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        return downscaledPNG(image, maxDimension: thumbnailDimension)
    }

    private static func downscaledPNG(_ image: NSImage, maxDimension: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = NSSize(width: max(1, floor(size.width * scale)),
                            height: max(1, floor(size.height * scale)))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width),
            pixelsHigh: Int(target.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = target

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}
