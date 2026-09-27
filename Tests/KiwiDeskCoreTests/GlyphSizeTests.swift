import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.glyph_size` (#1713, retiring #1682's item padding):
/// how large an item's content draws across the shelf. The
/// thickness stays the reservation; `KiwiShelf.contentDepth
/// (forDepth:)` is the one derivation every content size reads.
@Suite("KiwiShelf glyph size")
struct GlyphSizeTests {
    /// The default is the look that shipped before the setting:
    /// content at the full depth.
    @Test("Automatic sizes content at the full depth")
    func automaticFillsTheDepth() {
        let shelf = KiwiShelf()
        #expect(shelf.glyphSize == 0)
        for depth: CGFloat in [20, 40, 80] {
            #expect(shelf.contentDepth(forDepth: depth) == depth)
        }
    }

    @Test("A glyph size draws that size inside a thicker shelf")
    func sizeDrawsAsTyped() {
        var shelf = KiwiShelf()
        shelf.glyphSize = 28
        #expect(shelf.contentDepth(forDepth: 40) == 28)
    }

    /// Content never goes thinner than the thinnest shelf draws
    /// it, nor deeper than the strip it sits in.
    @Test("Content floors at the thickness floor", arguments: [30.0, 60.0])
    func contentFloors(depth: Double) {
        var shelf = KiwiShelf()
        shelf.glyphSize = KiwiShelf.minContentDepth - 8
        #expect(
            shelf.contentDepth(forDepth: CGFloat(depth))
                == KiwiShelf.minContentDepth
        )
    }

    /// A size past the thickness draws the thickness and is kept,
    /// so a thicker shelf later brings the typed size back.
    @Test("A size past the thickness waits for a thicker shelf")
    func sizePastTheThicknessWaits() {
        var shelf = KiwiShelf()
        shelf.glyphSize = 50
        #expect(shelf.contentDepth(forDepth: 40) == 40)
        #expect(shelf.glyphSize == 50)
        #expect(shelf.contentDepth(forDepth: 60) == 50)
    }

    @Test("Content is never deeper than a strip below the floor")
    func contentCappedByStrip() {
        var shelf = KiwiShelf()
        shelf.glyphSize = 28
        let depth = KiwiShelf.minContentDepth - 4
        #expect(shelf.contentDepth(forDepth: depth) == depth)
    }

    /// A live bar hands the looks the STRIP depth; the ladders
    /// take the glyph size once, inside — an automatic font size
    /// follows it.
    @Test("The looks' strip-depth ladders follow the glyph size")
    func laddersFollowTheGlyphSize() {
        var space = SpaceBarLook()
        space.glyphSize = 28
        var app = AppBarLook()
        app.glyphSize = 28
        #expect(space.contentDepth(forDepth: 40) == 28)
        #expect(
            space.identifierFontSize(forDepth: 40)
                == space.identifierFontSize(forContentDepth: 28)
        )
        #expect(
            space.glyphFontSize(forDepth: 40)
                == space.glyphFontSize(forContentDepth: 28)
        )
        #expect(
            space.titleFontSize(forDepth: 40)
                == space.titleFontSize(forContentDepth: 28)
        )
        #expect(
            app.resolvedFontSize(forDepth: 40)
                == app.resolvedFontSize(forContentDepth: 28)
        )
        #expect(
            app.resolvedFontSize(forDepth: 40)
                < app.resolvedFontSize(forContentDepth: 40)
        )
    }

    @Test("A negative size draws as automatic, whoever wrote it")
    func readerTreatsNegativeAsAutomatic() {
        var shelf = KiwiShelf()
        shelf.glyphSize = -10
        #expect(shelf.contentDepth(forDepth: 40) == 40)
    }

    @Test(
        "Decode floors at automatic",
        arguments: [(-4.0, 0.0), (24.0, 24.0), (90.0, 90.0)]
    )
    func decodeFloors(stored: Double, drawn: Double) throws {
        let json = #"{"glyph_size": \#(stored)}"#
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.glyphSize == CGFloat(drawn))
    }

    /// `item_padding` never shipped (#1713): a development file
    /// that carries it decodes, the key ignored.
    @Test("A shelf without the key decodes to automatic")
    func absentKeyIsAutomatic() throws {
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(#"{"item_padding": 6}"#.utf8)
        )
        #expect(shelf.glyphSize == 0)
    }

    /// Parse floors every length at 0 already, so the apply arm's
    /// own floor is held by a setting that skips parse.
    @Test("Apply floors a negative size itself")
    func applyFloors() {
        var shelf = KiwiShelf()
        KiwiShelfCommandSetting.glyphSize(-3).apply(to: &shelf)
        #expect(shelf.glyphSize == 0)
    }

    @Test(
        "The setter floors at automatic",
        arguments: [(-3.0, 0.0), (24.0, 24.0)]
    )
    func setterFloors(value: Double, stored: Double) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "glyph_size",
            args: [.number(value)]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.glyphSize == CGFloat(stored))
    }
}
