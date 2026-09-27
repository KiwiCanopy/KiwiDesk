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
                == KiwiShelf.minThickness
        )
    }

    @Test("Content is never deeper than a strip below that floor")
    func contentCappedByStrip() {
        var shelf = KiwiShelf()
        shelf.itemPadding = 6
        let depth = KiwiShelf.minThickness - 4
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

/// The live Space Bar: `SpaceBarManager.sync` on a 40 pt strip at
/// 6 pt of padding draws every content size at the 28 pt content
/// depth — the items' cells and length, the identifier, the
/// front-app segment and the overflow count — while boxes keep
/// the full depth.
@Suite("Item padding reaches the rendered Space Bar", .serialized)
@MainActor
struct ItemPaddingSpaceBarTests {
    private static let depth: CGFloat = 40
    private static let padding: CGFloat = 6
    private static let content: CGFloat = 28

    init() { LiquidGlassGate.override = { false } }

    private static func icon() -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) {
            NSColor.black.setFill()
            $0.fill()
            return true
        }
    }

    private static func look(
        boxed: Bool = false
    ) -> SpaceBarLook {
        var look = SpaceBarLook()
        look.itemPadding = padding
        look.liquidGlass = false
        look.backgroundStyle = boxed ? .boxed : .plain
        look.showFrontApp = true
        return look
    }

    private static func app(_ name: String) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: name,
            title: "A window",
            icon: icon(),
            glyph: nil,
            focused: false,
            count: 1
        )
    }

    private static func bar(
        spaces: Int = 1,
        boxed: Bool = false
    ) -> SpaceBarManager.Bar {
        SpaceBarManager.Bar(
            display: barTitleDisplay,
            items: (1...spaces).map { n in
                SpaceBarOverlay.Item(
                    space: SpaceID(String(n)),
                    spaceGlyph: .text(String(n), tinted: true),
                    // Every second Space empty: a glyphless item
                    // beside glyph-bearing ones.
                    apps: n == 2 ? [] : [app("A"), app("B")],
                    active: n == 1,
                    overflow: 0,
                    focusInOverflow: false
                )
            },
            frontApp: app("Front"),
            frontWindow: WindowID(1),
            strip: CGRect(x: 0, y: 0, width: 1440, height: depth),
            style: look(boxed: boxed),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    private func overlay(
        _ bar: SpaceBarManager.Bar,
        in manager: SpaceBarManager
    ) throws -> SpaceBarOverlay {
        manager.sync([bar])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    @Test("An item's cells and length follow the content depth")
    func itemFollowsContent() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(Self.bar(), in: manager)
        let view = try #require(overlay.itemViews.first)
        view.layoutSubtreeIfNeeded()
        let cell = SpaceBarItemView.cell(contentDepth: Self.content)
        #expect(cell == Self.content - 2 * SpaceBarItemView.pad)
        #expect(view.frame.height == Self.depth)
        #expect(
            view.frame.width
                == SpaceBarItemView.autoLength(
                    appCount: 2,
                    contentDepth: Self.content,
                    glyphGap: Self.look().resolvedGlyphGap
                )
        )
        for glyph in view.appViews {
            #expect(glyph.frame.size == CGSize(width: cell, height: cell))
            #expect(abs(glyph.frame.midY - Self.depth / 2) <= 0.5)
        }
    }

    /// The in-item rule is content: as long as the content allows,
    /// centred on the item's full depth.
    @Test("The identifier divider sits on the midline at content length")
    func dividerOnMidline() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(Self.bar(), in: manager)
        let view = try #require(overlay.itemViews.first)
        view.layoutSubtreeIfNeeded()
        let rule = view.identifierDivider
        #expect(!rule.isHidden)
        #expect(abs(rule.frame.midY - Self.depth / 2) <= 0.5)
        #expect(
            abs(
                rule.frame.height
                    - BarDivider.ruleLengthShare * Self.content
            ) <= 0.5
        )
    }

    /// An empty Space's item is shorter than the depth under
    /// padding; its box still rounds from the full depth.
    @Test("A glyphless item rounds like a glyph-bearing one")
    func glyphlessRadius() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(Self.bar(spaces: 2), in: manager)
        let full = overlay.itemViews[0]
        let empty = overlay.itemViews[1]
        full.layoutSubtreeIfNeeded()
        empty.layoutSubtreeIfNeeded()
        #expect(empty.frame.width < Self.depth)
        #expect(empty.cornerRadius == full.cornerRadius)
        #expect(
            full.cornerRadius
                == Self.look().resolvedCornerRadius(forThickness: Self.depth)
        )
    }

    @Test("The identifier's automatic size follows the content depth")
    func identifierFollowsContent() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(Self.bar(), in: manager)
        let view = try #require(overlay.itemViews.first)
        view.layoutSubtreeIfNeeded()
        let look = Self.look()
        let size = look.identifierFontSize(forContentDepth: Self.content)
        #expect(size < look.identifierFontSize(forContentDepth: Self.depth))
        #expect(view.identifierLabel.font?.pointSize == size)
    }

    @Test("The front-app segment draws at the content depth")
    func frontSegmentFollowsContent() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(Self.bar(), in: manager)
        let cell = SpaceBarItemView.cell(contentDepth: Self.content)
        #expect(!overlay.frontIcon.isHidden)
        #expect(
            overlay.frontIcon.frame.size
                == CGSize(width: cell, height: cell)
        )
        #expect(
            overlay.frontName.font?.pointSize
                == Self.look().titleFontSize(forContentDepth: Self.content)
        )
    }

    /// The chip is a box like an item's: it keeps the strip's
    /// depth, and only its content shrinks.
    @Test("The front-app chip keeps the full depth")
    func frontChipKeepsDepth() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(Self.bar(boxed: true), in: manager)
        #expect(!overlay.frontBox.isHidden)
        #expect(overlay.frontBox.frame.height == Self.depth)
    }

    @Test("The overflow count's automatic size follows the content")
    func countFollowsContent() throws {
        let manager = SpaceBarManager()
        let overlay = try overlay(Self.bar(spaces: 60), in: manager)
        #expect(!overlay.forwardCount.isHidden)
        #expect(
            overlay.forwardCount.fontSize
                == Self.look().identifierFontSize(
                    forContentDepth: Self.content
                ) * 0.8
        )
    }
}
