import CoreGraphics
import Foundation
import KiwiDeskCore

/// A look tile's picture (#3478): decoded once at tile size and kept
/// by library name, which is the picture's hash, so a redraw never
/// decodes again and a changed picture is a new name.
@MainActor
enum LookTilePictures {
    private static var decoded: [String: CGImage] = [:]

    /// The long side a tile's picture is decoded to, in pixels.
    static let maxPixels = 480

    static func image(
        named name: String,
        in library: WallpaperLibrary
    ) -> CGImage? {
        if let image = decoded[name] { return image }
        guard
            let image = LookPickerPictures.decode(
                library.url(of: name),
                maxPixels: maxPixels
            )
        else { return nil }
        decoded[name] = image
        return image
    }
}
