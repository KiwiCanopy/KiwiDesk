import Combine
import CoreGraphics
import Foundation
import KiwiDeskCore

/// Look tiles' pictures (#3478): each decoded once at tile size off
/// the main actor and kept by library name, which is the picture's
/// hash, so a redraw never decodes and a changed picture is a new
/// name. A name that did not decode is remembered too, so a picture
/// not yet synced is not read again on every redraw.
@MainActor
final class LookTilePictures: ObservableObject {
    static let shared = LookTilePictures()

    /// The long side a tile's picture is decoded to, in pixels.
    static let maxPixels = 480

    @Published private var decoded: [String: CGImage] = [:]
    private var asked: Set<String> = []

    /// The picture named `name`, nil until its decode lands; the
    /// first ask starts it.
    func image(named name: String, in library: WallpaperLibrary) -> CGImage? {
        if let image = decoded[name] { return image }
        guard asked.insert(name).inserted else { return nil }
        let url = library.url(of: name)
        let pixels = Self.maxPixels
        Task.detached(priority: .utility) { [weak self] in
            guard
                let image = WallpaperShrink.thumbnail(
                    at: url,
                    maxPixels: pixels
                )
            else { return }
            await MainActor.run { self?.decoded[name] = image }
        }
        return nil
    }
}
