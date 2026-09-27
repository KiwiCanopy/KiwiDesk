import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.item_padding` (#1682): room inside the thickness
/// between the shelf and each item's content. The thickness stays
/// the reservation; `KiwiShelf.contentDepth(forDepth:)` is the one
/// derivation every content size reads.
@Suite("KiwiShelf item padding")
struct ItemPaddingTests {
    /// The default is the look that shipped before the setting:
    /// content at the full depth.
    @Test("The default sizes content at the full depth")
    func defaultIsTodaysLook() {
        let shelf = KiwiShelf()
        #expect(shelf.itemPadding == 0)
        for depth: CGFloat in [20, 40, 80] {
            #expect(shelf.contentDepth(forDepth: depth) == depth)
        }
    }

    @Test("The padding comes off both sides")
    func paddingOnBothSides() {
        var shelf = KiwiShelf()
        shelf.itemPadding = 6
        #expect(shelf.contentDepth(forDepth: 40) == 28)
    }

    /// Content never goes thinner than the thinnest shelf draws it
    /// unpadded, nor deeper than the strip it sits in.
    @Test("Content floors at the thickness floor", arguments: [40.0, 60.0])
    func contentFloors(depth: Double) {
        var shelf = KiwiShelf()
        shelf.itemPadding = CGFloat(depth)
        #expect(
            shelf.contentDepth(forDepth: CGFloat(depth))
                == KiwiShelf.minContentDepth
        )
    }

    @Test("Content is never deeper than a strip below that floor")
    func contentCappedByStrip() {
        var shelf = KiwiShelf()
        shelf.itemPadding = 6
        let depth = KiwiShelf.minContentDepth - 4
        #expect(shelf.contentDepth(forDepth: depth) == depth)
    }

    /// A live bar hands the looks the STRIP depth; the ladders
    /// take the padding off once, inside.
    @Test("The looks' strip-depth ladders take the padding off")
    func laddersTakeThePaddingOff() {
        var space = SpaceBarLook()
        space.itemPadding = 6
        var app = AppBarLook()
        app.itemPadding = 6
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

    @Test("A negative padding draws as none, whoever wrote it")
    func readerFloors() {
        var shelf = KiwiShelf()
        shelf.itemPadding = -10
        #expect(shelf.contentDepth(forDepth: 40) == 40)
    }

    @Test(
        "Decode floors at zero",
        arguments: [(-4.0, 0.0), (7.0, 7.0), (50.0, 50.0)]
    )
    func decodeFloors(stored: Double, drawn: Double) throws {
        let json = #"{"item_padding": \#(stored)}"#
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.itemPadding == CGFloat(drawn))
    }

    @Test("A shelf without the key decodes to no padding")
    func absentKeyIsTodaysLook() throws {
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(shelf.itemPadding == 0)
    }

    @Test(
        "The setter floors at zero",
        arguments: [(-3.0, 0.0), (7.0, 7.0)]
    )
    func setterFloors(value: Double, stored: Double) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "item_padding",
            args: [.number(value)]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.itemPadding == CGFloat(stored))
    }
}
