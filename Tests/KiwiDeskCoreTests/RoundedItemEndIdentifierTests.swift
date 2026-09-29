import AppKit
import Testing

@testable import KiwiDeskCore

/// Which end of a Space item clears its rounded curve (#1763, owner
/// 2026-09-29): an end holding an icon-like glyph — a symbol
/// identifier, app glyphs or a `+N` disc, the identifier's corner
/// badge — and never a text identifier alone.
@Suite("Rounded ends clear only an icon's end (#1763)", .serialized)
@MainActor
struct RoundedItemEndIdentifierTests {
    private typealias Fixture = RoundedItemEndPadTests

    init() { LiquidGlassGate.override = { false } }

    /// A number's ink sits well inside its cell, so its end keeps
    /// the plain pad; the app icons' end still clears the curve
    /// (owner, 2026-09-29).
    @Test("A number identifier's end takes no clearance")
    func numberIdentifierTakesNone() throws {
        let pad = SpaceBarItemView.pad
        let look = Fixture.spaceLook(100)
        let e = Fixture.clearance(look, depth: Fixture.depth)
        #expect(e > 0)
        let overlay = try Fixture.spaceBar(
            look,
            items: Fixture.items(1, numbered: true)
        )
        let view = try #require(overlay.itemViews.first)
        #expect(view.ends == ItemEnds(leading: 0, trailing: e))
        let cell = view.cellLength
        let flat = pad * 2 + cell + (pad + 1 + pad) + 3 * cell
        #expect(view.frame.width == flat + e)
        let first = try #require(view.appViews.first).frame
        #expect(abs(first.minX - (cell + pad + 1 + pad) - pad) <= 0.5)
    }

    /// A collapsed Space draws its count disc on the identifier's
    /// trailing corner, so on a horizontal bar that end clears the
    /// curve though no app glyph sits there.
    @Test("A collapsed Space's count disc takes the trailing clearance")
    func collapsedDiscTakesTheTrailingEnd() throws {
        let look = Fixture.spaceLook(100)
        let e = Fixture.clearance(look, depth: Fixture.depth)
        #expect(e > 0)
        var items = Fixture.items(2, numbered: true)
        items[1] = items[1].collapsed(to: .count)
        let overlay = try Fixture.spaceBar(look, items: items)
        let views = Array(overlay.itemViews.prefix(2))
        #expect(views.count == 2)
        #expect(views[1].appViews.isEmpty)
        #expect(views[1].ends == ItemEnds(leading: 0, trailing: e))
        let measured = SpaceBarOverlay.itemLengths(
            items,
            depth: Fixture.depth,
            look: look,
            frontFollows: false
        )
        #expect(measured[1] == views[1].frame.width)
    }
}
