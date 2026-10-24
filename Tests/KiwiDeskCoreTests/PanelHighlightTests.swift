import Foundation
import Testing

@testable import KiwiDeskCore

/// **KiwiHub's selection and hover take KiwiShelf's highlight and
/// hover fill under "Tint KiwiHub and plates"** (#2569 ▸ Ruling):
/// the selection's ink is the one `contrastingGlyph` picks on the
/// highlight, the hover row the bars' own hover pair.
@Suite("KiwiHub selection and hover (#2569)")
struct PanelHighlightTests {
    @Test("The highlight fills the selection, the hover fill the hover")
    func takesTheShelfColours() {
        var shelf = KiwiShelf()
        shelf.highlightColor = "#112233"
        shelf.hoverFillColor = "#44556680"
        shelf.hoverItemColor = "#EEEEEE"
        let paint = shelf.panelHighlight
        #expect(paint.selection == "#112233")
        #expect(paint.selectionInk == "#FFFFFF")
        #expect(paint.hover == "#44556680")
        #expect(paint.hoverInk == "#EEEEEE")
        shelf.highlightColor = "#F0F0F0"
        #expect(shelf.panelHighlight.selectionInk == "#000000")
    }

    /// The selection's ink holds the bars' ink floor on every
    /// bundled palette's highlight.
    @Test("The selection's ink stays legible on every bundled highlight")
    func selectionInkIsLegible() throws {
        for palette in PaletteCatalog.bundled() {
            var settings = TilingSettings()
            palette.apply(to: &settings)
            let paint = settings.kiwishelf.panelHighlight
            let fill = try #require(
                ColorVision.composite(paint.selection, over: "#808080")
            )
            let ink = try #require(
                ColorVision.composite(paint.selectionInk, over: fill)
            )
            let ratio = try #require(ColorVision.contrast(ink, fill))
            #expect(
                ratio >= KiwiShelf.idleInkFloor,
                "\(palette.name): \(ratio)"
            )
        }
    }
}
