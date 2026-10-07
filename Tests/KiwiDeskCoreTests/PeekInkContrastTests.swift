import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The hover peek's ink stays legible on its own ground (#1946):
/// titles and the app header alike in the shelf's full item ink,
/// on the plate's Fill — capped at `GlassTint.maxAlpha` as glass
/// and uniform over the whole panel (`GlassTint.applyUniform`), or
/// as stored where the glass is off. Measured as
/// `IdleItemContrastTests` measures the idle identifier: the ground
/// composited over each wallpaper extreme, the ink over the ground,
/// against the same floor, on every bundled palette.
@Suite("Hover peek ink contrast")
struct PeekInkContrastTests {
    private static let floor = KiwiShelf.idleInkFloor

    /// `fill` at `min(its alpha, cap)`, as an `#RRGGBBAA` hex.
    private func capped(_ fill: String, at cap: CGFloat) -> String? {
        guard let rgba = DragVisual.parseHex(fill) else { return nil }
        let alpha = min(rgba.alpha, Double(cap))
        let bytes = [rgba.red, rgba.green, rgba.blue, alpha].map {
            String(format: "%02X", Int(($0 * 255).rounded()))
        }
        return "#" + bytes.joined()
    }

    private func contrast(
        ink: String,
        ground: String,
        on wallpaper: String
    ) -> Double? {
        guard let plate = ColorVision.composite(ground, over: wallpaper),
            let drawn = ColorVision.composite(ink, over: plate)
        else { return nil }
        return ColorVision.contrast(drawn, plate)
    }

    @Test("Every bundled palette's peek ink clears the floor")
    func peekInkStaysLegible() throws {
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            let item = try #require(
                palette.colors["kiwishelf.item_color"],
                Comment(rawValue: palette.name)
            )
            let fill = try #require(
                palette.colors["kiwishelf.fill_color"],
                Comment(rawValue: palette.name)
            )
            var shelf = KiwiShelf()
            shelf.itemColor = item
            let glass = try #require(capped(fill, at: GlassTint.maxAlpha))
            for ground in [fill, glass] {
                // Titles and header share the one ink (owner
                // ruling on #1946), so the one ink is measured.
                let ink = shelf.itemColor
                for wallpaper in ["#FFFFFF", "#000000"] {
                    let value = try #require(
                        contrast(
                            ink: ink,
                            ground: ground,
                            on: wallpaper
                        )
                    )
                    measured += 1
                    #expect(
                        value >= Self.floor,
                        Comment(
                            rawValue:
                                "\(palette.name) \(ink) on "
                                + "\(ground) over \(wallpaper): "
                                + "\(value)"
                        )
                    )
                }
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 4)
        #expect(measured > 0)
    }
}
