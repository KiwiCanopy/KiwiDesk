import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's dividers under "Tint KiwiHub and plates" draw in the
/// look's dim panel ink at `panelDividerAlpha` (#2596): visible on
/// every bundled palette, stepping up under Increase Contrast.
/// Measured as `PeekInkContrastTests` measures the reading floor —
/// the ground composited over a white and a black wallpaper, the
/// divider over the ground — at the fade's anchor and at its far
/// end, Fill fade at 100, floored at the panel Fill's `minShare`.
@Suite("KiwiHub divider contrast (#2596)")
struct PanelDividerContrastTests {
    /// The floors ui-designer set and the owner took (2026-10-25):
    /// a non-text hairline, so below the reading floor, which pins
    /// the dim ink at exactly `readingInkFloor` at the far end over
    /// white. A retune of that floor moves the divider's contrast
    /// against this one, so it is re-measured with that retune.
    private static let floor = 1.15
    private static let increasedFloor = 1.5

    /// The shelf a bundled palette paints, through its own apply.
    private func painted(_ palette: ColorPalette) -> KiwiShelf {
        var settings = TilingSettings()
        palette.apply(to: &settings)
        return settings.kiwishelf
    }

    @Test(
        "Every bundled palette's divider clears its floor",
        arguments: [false, true]
    )
    func dividerStaysVisible(increaseContrast: Bool) throws {
        let floor = increaseContrast ? Self.increasedFloor : Self.floor
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            var shelf = painted(palette)
            shelf.fillFade = 100
            let ink = shelf.panelInk(increaseContrast: increaseContrast)
            let fill = shelf.panelGlassFill(
                increaseContrast: increaseContrast
            )
            let rgba = try #require(HexColor.parse(shelf.fillColor))
            let anchor = min(CGFloat(rgba.alpha), GlassTint.maxAlpha)
            let far = max(GlassTint.farShare(fade: 100), fill.minShare)
            for share in [1, far] {
                let ground = shelf.fill(cappedAt: anchor * share)
                let value = try #require(
                    shelf.worstContrast(ink.divider, nil, on: ground)
                )
                measured += 1
                #expect(
                    value >= floor,
                    "\(palette.name) at \(share): \(value)"
                )
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 2)
        #expect(measured > 0)
    }

    /// The divider is the dim ink thinned, a heavier step under
    /// Increase Contrast — never a hue of its own.
    @Test("The divider is the dim ink thinned")
    func dividerIsTheDimInk() {
        var shelf = KiwiShelf()
        shelf.itemColor = "#FF9F43"
        for increased in [false, true] {
            let ink = shelf.panelInk(increaseContrast: increased)
            let alpha =
                increased
                ? KiwiShelf.panelDividerIncreasedAlpha
                : KiwiShelf.panelDividerAlpha
            #expect(ink.divider == KiwiShelf.hex(ink.tertiary, atShare: alpha))
        }
        #expect(
            KiwiShelf.panelDividerIncreasedAlpha > KiwiShelf.panelDividerAlpha
        )
    }
}
