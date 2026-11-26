import Combine
import CoreGraphics
import Foundation
import ImageIO
import KiwiDeskCore

/// The look picker's decoded pictures (#3478, #3038 ▸ Ruling
/// 2026-11-26): each card's picture decoded once, downsampled to the
/// screen's pixel size, keyed by the card's id and never by a view's
/// state, so a fast step draws a ready image rather than decoding a
/// full-size one per frame. Decoding starts as the picker opens.
@MainActor
final class LookPickerPictures: ObservableObject {
    private let library: WallpaperLibrary?
    private let maxPixels: Int
    private let screen: Int
    @Published private(set) var decoded: [String: CGImage] = [:]

    init(library: WallpaperLibrary?, maxPixels: Int, screen: Int) {
        self.library = library
        self.maxPixels = maxPixels
        self.screen = screen
    }

    /// A picker with no pictures, for a test and a host without one.
    static var none: LookPickerPictures {
        LookPickerPictures(library: nil, maxPixels: 0, screen: 1)
    }

    /// The library name `entry` sets on the picker's screen.
    func name(
        of entry: LookPickerEntry?,
        over settings: TilingSettings
    ) -> String? {
        guard let entry else { return nil }
        let wallpaper =
            entry.kind == .current
            ? settings.lookWallpaper : entry.look.admitted.wallpaper
        return wallpaper?.name(forScreen: screen)
    }

    /// The decoded picture `entry` draws, nil until it is ready or
    /// where the card has none.
    func image(
        of entry: LookPickerEntry?,
        over settings: TilingSettings
    ) -> CGImage? {
        name(of: entry, over: settings).flatMap { decoded[$0] }
    }

    /// Decodes every card's picture off the main actor, once each.
    func prepare(_ cards: [LookPickerEntry], over settings: TilingSettings) {
        guard let library else { return }
        let names = Set(cards.compactMap { name(of: $0, over: settings) })
            .filter { decoded[$0] == nil }
        let pixels = maxPixels
        for name in names {
            let url = library.url(of: name)
            Task.detached(priority: .userInitiated) { [weak self] in
                guard
                    let image = WallpaperShrink.thumbnail(
                        at: url,
                        maxPixels: pixels
                    )
                else { return }
                await MainActor.run { self?.decoded[name] = image }
            }
        }
    }
}
