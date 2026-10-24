import AppKit
import Testing

@testable import KiwiDeskCore

/// **A Fill with no colour is one state** (#2569 ▸ Ruling, "No
/// Colour"): a parseable Fill at alpha 0, an empty one and an
/// unparseable one all read as no colour — clear glass on the glass
/// path, no plate on the solid one, never the system accent.
@Suite("No colour Fill (#2569)")
@MainActor
struct NoColourFillTests {
    init() { LiquidGlassGate.override = { false } }

    @Test(
        "One predicate decides whether a Fill has a colour",
        arguments: [
            ("#14201CB3", true), ("#14201C", true), ("#14201C00", false),
            ("", false), ("nope", false),
        ]
    )
    func predicate(hex: String, has: Bool) {
        #expect(KiwiShelf.hasColour(hex) == has)
        var shelf = KiwiShelf()
        shelf.fillColor = hex
        #expect(shelf.hasFill == has)
    }

    /// The solid path reads a Fill through `kiwiFill`, which is
    /// clear where there is no colour, never the accent fallback.
    @Test(
        "A solid Fill without colour paints nothing",
        arguments: ["", "nope", "#FF000000"]
    )
    func solidFillIsClear(hex: String) {
        #expect(NSColor(kiwiFill: hex).alphaComponent == 0)
        #expect(NSColor(kiwiFill: "#FF0000").alphaComponent == 1)
    }

    @Test("Glass paints no colour for an unparseable Fill")
    func glassPaintsNothing() throws {
        // Below macOS 26 `rendered` answers nil for every Fill.
        guard #available(macOS 26, *) else { return }
        try #require(
            GlassTint.paint(GlassFill(hex: "#FF0000"), edge: .top) != nil
        )
        #expect(GlassTint.paint(GlassFill(hex: "nope"), edge: .top) == nil)
        #expect(GlassTint.pin("nope") == nil)
    }

    /// The consumer: the shelf's solid plate draws no colour for an
    /// empty Fill.
    @Test("The shelf's solid plate is clear for an empty Fill")
    func solidPlateIsClear() throws {
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3, glass: false)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.fillColor = ""
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: .top,
                strip: barTitleStrip,
                shelf: shelf,
                sheen: 0,
                space: section,
                app: nil
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        let plate = try #require(overlay.solidPlate)
        #expect(plate.layer?.backgroundColor?.alpha == 0)
    }
}
