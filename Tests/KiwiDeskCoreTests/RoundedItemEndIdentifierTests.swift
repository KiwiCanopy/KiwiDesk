import AppKit
import Testing

@testable import KiwiDeskCore

/// When a Space item clears its rounded curve (#1763): once an
/// icon-like glyph — a symbol identifier, app glyphs or a `+N`
/// disc, the identifier's corner badge — sits at either end, and
/// then at both ends alike so the content centres (#1856, owner
/// 2026-10-01, reversing 2026-09-29's per-end pad).
@Suite("Rounded ends clear alike once an icon sits at one", .serialized)
@MainActor
struct RoundedItemEndIdentifierTests {
    private typealias Fixture = RoundedItemEndPadTests

    init() { LiquidGlassGate.override = { false } }

    /// The app icons' end clears the curve, and the number's end
    /// takes the same clearance so the content centres.
    @Test("A number identifier's end pads like its app end")
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
        #expect(view.ends == ItemEnds(leading: e, trailing: e))
        let cell = view.cellLength
        let flat = pad * 2 + cell + (pad + 1 + pad) + 3 * cell
        #expect(view.frame.width == flat + 2 * e)
        let first = try #require(view.appViews.first).frame
        #expect(
            abs(first.minX - (cell + pad + 1 + pad) - pad - e) <= 0.5
        )
    }

    /// A collapsed Space draws its count disc on the identifier's
    /// trailing corner, so on a horizontal bar that end clears the
    /// curve though no app glyph sits there — and the identifier's
    /// end alike.
    @Test("A collapsed Space's count disc pads both ends")
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
        #expect(views[1].ends == ItemEnds(leading: e, trailing: e))
        let measured = SpaceBarOverlay.itemLengths(
            items,
            depth: Fixture.depth,
            look: look,
            frontFollows: false
        )
        #expect(measured[1] == views[1].frame.width)
    }
}
