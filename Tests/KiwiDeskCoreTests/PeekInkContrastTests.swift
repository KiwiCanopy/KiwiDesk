import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The hover peek's ink stays legible on its own ground (#1946):
/// titles in the shelf's item ink, the app header at its derived
/// `peekHeaderColor`, and a hovered row's `hoverItemColor` over
/// its `hoverFillColor` — on the plate's Fill, capped at
/// `GlassTint.maxAlpha` as glass and uniform over the whole panel
/// (`GlassTint.applyUniform`), or as stored where the glass is off.
/// Measured as `IdleItemContrastTests` measures the idle identifier:
/// the ground composited over each wallpaper extreme, the ink over
/// the ground, against the same floor, on every bundled palette.
@Suite("Hover peek ink contrast")
struct PeekInkContrastTests {
    private static let floor = KiwiShelf.idleInkFloor
    private static let wallpapers = ["#FFFFFF", "#000000"]

    /// `fill` at `min(its alpha, cap)`, as an `#RRGGBBAA` hex.
    private func capped(_ fill: String, at cap: CGFloat) -> String? {
        guard let rgba = DragVisual.parseHex(fill) else { return nil }
        let alpha = min(rgba.alpha, Double(cap))
        let bytes = [rgba.red, rgba.green, rgba.blue, alpha].map {
            String(format: "%02X", Int(($0 * 255).rounded()))
        }
        return "#" + bytes.joined()
    }

    /// `ink` over `layer` (where given) over `ground` over
    /// `wallpaper`, against the plate it sits on.
    private func contrast(
        ink: String,
        ground: String,
        layer: String? = nil,
        on wallpaper: String
    ) -> Double? {
        guard let shelf = ColorVision.composite(ground, over: wallpaper),
            let plate = layer.map({ ColorVision.composite($0, over: shelf) })
                ?? shelf,
            let drawn = ColorVision.composite(ink, over: plate)
        else { return nil }
        return ColorVision.contrast(drawn, plate)
    }

    /// The shelf a bundled palette paints, through the palette's own
    /// apply — fill and badge colours included.
    private func painted(_ palette: ColorPalette) -> KiwiShelf {
        var settings = TilingSettings()
        palette.apply(to: &settings)
        return settings.kiwishelf
    }

    @Test("Every bundled palette's peek ink clears the floor")
    func peekInkStaysLegible() throws {
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            let shelf = painted(palette)
            let name = Comment(rawValue: palette.name)
            #expect(
                shelf.fillColor == palette.colors["kiwishelf.fill_color"],
                name
            )
            let glass = try #require(
                capped(shelf.fillColor, at: GlassTint.maxAlpha)
            )
            // Titles in the item ink, the header at its derived step
            // (owner rulings on #1946) — three pairings per ground.
            let pairings: [(String, String?)] = [
                (shelf.itemColor, nil),
                (shelf.peekHeaderColor, nil),
                // A hovered row: the shelf's item hover (amendment 2).
                (shelf.hoverItemColor, shelf.hoverFillColor),
            ]
            for ground in [shelf.fillColor, glass] {
                for (ink, layer) in pairings {
                    for wallpaper in Self.wallpapers {
                        let value = try #require(
                            contrast(
                                ink: ink,
                                ground: ground,
                                layer: layer,
                                on: wallpaper
                            )
                        )
                        measured += 1
                        #expect(
                            value >= Self.floor,
                            Comment(
                                rawValue:
                                    "\(palette.name) \(ink) on "
                                    + "\(layer ?? "-") on \(ground) "
                                    + "over \(wallpaper): \(value)"
                            )
                        )
                    }
                }
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 12)
        #expect(measured > 0)
    }

    /// The glass ground alone failing drops the step: an opaque mid
    /// grey Fill holds the dimmed white ink as stored, but not once
    /// glass caps it and the wallpaper shows through.
    @Test("The glass ground alone drops the header's step")
    func glassGroundAloneDropsTheStep() throws {
        var shelf = KiwiShelf()
        shelf.itemColor = "#FFFFFF"
        shelf.fillColor = "#808080FF"
        let dimmed = shelf.itemColor(atShare: KiwiShelf.peekHeaderAlpha)
        let glass = shelf.fill(cappedAt: GlassTint.maxAlpha)
        let stored = try #require(
            shelf.worstContrast(dimmed, nil, on: shelf.fillColor)
        )
        let tinted = try #require(
            shelf.worstContrast(dimmed, nil, on: glass)
        )
        #expect(stored >= Self.floor)
        #expect(tinted < Self.floor)
        #expect(shelf.peekHeaderColor == shelf.itemColor)
    }
}
