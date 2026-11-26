import Foundation
import ImageIO

/// "Shrink first" for a large picture (#3478 ▸ Size): downscaled to
/// the largest connected screen in its own format. A dynamic HEIC
/// keeps its first frame only, which the alert says.
public enum WallpaperShrink {
    /// `data` downscaled so its long side is at most `maxPixels`,
    /// nil when it is no picture or ImageIO cannot write its type.
    /// A picture already that small comes back unchanged.
    public static func shrunk(_ data: Data, maxPixels: Int) -> Data? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any]
        else { return nil }
        let width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        let frames = CGImageSourceGetCount(source)
        if max(width, height) <= maxPixels, frames <= 1 { return data }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard
            let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            )
        else { return nil }
        let out = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                out,
                type,
                1,
                nil
            )
        else { return nil }
        // The colour profile rides the image; orientation is baked.
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }

    /// Whether `data` holds more than one frame — a dynamic HEIC,
    /// whose shrink keeps one.
    public static func isDynamic(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return false }
        return CGImageSourceGetCount(source) > 1
    }
}
