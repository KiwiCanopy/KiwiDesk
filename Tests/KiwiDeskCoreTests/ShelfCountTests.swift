import AppKit
import Testing

@testable import KiwiDeskCore

/// Overflow shows as fades and counts, never arrows (#1517).
@Suite("Shelf counts and fades")
@MainActor
struct ShelfCountTests {
    init() { LiquidGlassGate.override = { false } }

    @Test("A count keeps its chevron, pointing where the entries are")
    func countGlyph() {
        let cases: [(ShelfCountView.Side, Bool, String, Bool)] = [
            (.before, true, "chevron.left", true),
            (.after, true, "chevron.right", false),
            (.before, false, "chevron.up", true),
            (.after, false, "chevron.down", false),
        ]
        for (side, horizontal, symbol, leads) in cases {
            let glyph = ShelfCountView.glyph(
                side: side,
                horizontal: horizontal
            )
            #expect(glyph.symbol == symbol)
            #expect(glyph.leads == leads)
            #expect(
                NSImage(
                    systemSymbolName: symbol,
                    accessibilityDescription: nil
                ) != nil
            )
        }
    }

    /// The drawn order: the chevron sits away from the content —
    /// left of or above the number before, right of or below it
    /// after — so a vertical shelf stacks the two.
    @Test("The chevron draws on the side away from the content")
    func chevronPlacement() throws {
        for (side, horizontal) in [
            (ShelfCountView.Side.before, true), (.after, true),
            (.before, false), (.after, false),
        ] {
            let view = ShelfCountView(side: side)
            view.configure(
                count: 12,
                horizontal: horizontal,
                fontSize: 12,
                ink: .white,
                hoverInk: .white
            )
            view.frame =
                horizontal
                ? CGRect(x: 0, y: 0, width: view.fittingLength, height: 24)
                : CGRect(x: 0, y: 0, width: 24, height: view.fittingLength)
            view.layout()
            let parts = view.subviews
            let number = try #require(
                parts.first { $0 is NSTextField }
            ).frame
            let chevron = try #require(
                parts.first { $0 is NSImageView }
            ).frame
            #expect(chevron.width > 0 && chevron.height > 0)
            let gap = ShelfCountView.partGap - 0.5
            // Flipped: a smaller y is higher on screen.
            switch (side, horizontal) {
            case (.before, true):
                #expect(chevron.maxX <= number.minX - gap)
            case (.after, true):
                #expect(chevron.minX >= number.maxX + gap)
            case (.before, false):
                #expect(chevron.maxY <= number.minY - gap)
            case (.after, false):
                #expect(chevron.minY >= number.maxY + gap)
            }
            #expect(view.bounds.contains(chevron))
        }
    }

    @Test("A count is a button that pages, and hides at zero")
    func countIsAButton() {
        let view = ShelfCountView(side: .after)
        var paged = 0
        view.onPage = { paged += 1 }
        view.configure(
            count: 4,
            horizontal: true,
            fontSize: 12,
            ink: .white,
            hoverInk: .white
        )
        #expect(!view.isHidden)
        #expect(view.accessibilityRole() == .button)
        #expect(view.accessibilityLabel()?.contains("4") == true)
        #expect(view.accessibilityPerformPress())
        #expect(paged == 1)
        view.configure(
            count: 0,
            horizontal: true,
            fontSize: 12,
            ink: .white,
            hoverInk: .white
        )
        #expect(view.isHidden)
    }

    @Test("The mask is clear at a hidden end and opaque in between")
    func maskStops() {
        #expect(
            ShelfFadeMask.stops(leading: 0, trailing: 50, length: 200)
                == [0, 0, 0.75, 1]
        )
        // A fade never passes the middle.
        #expect(
            ShelfFadeMask.stops(leading: 300, trailing: 300, length: 200)
                == [0, 0.5, 0.5, 1]
        )
    }

    /// The live bar: sixty Spaces overflow the fixture strip, so
    /// the trailing end fades, counts, and no drop target reaches
    /// into it.
    @Test("An overflowing Space Bar fades and counts its hidden end")
    func spaceBarFadesAndCounts() throws {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: 60)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(overlay.itemContainer.layer?.mask != nil)
        #expect(overlay.backCount.isHidden)
        #expect(!overlay.forwardCount.isHidden)
        let clear = try #require(overlay.scrollGeom).fades
        #expect(clear.trailing > 0 && clear.after > 0)
        let edge = overlay.itemContainer.frame.maxX - clear.trailing
        for (_, frame) in overlay.hitFrames {
            #expect(frame.maxX <= edge + 0.5)
        }
        // Few enough Spaces to fit: no mask, no counts.
        manager.sync([paintedSpaceBar(front: nil, spaces: 3)])
        #expect(overlay.itemContainer.layer?.mask == nil)
        #expect(overlay.forwardCount.isHidden)
    }
}

/// Drop targets keep their places when the leading end fades: an
/// item's hit frame is offset by the viewport, and only cut at
/// the fade (#1517 review blocker).
@Suite("Shelf drop targets under a fade")
@MainActor
struct ShelfDropTargetTests {
    init() { LiquidGlassGate.override = { false } }

    @Test("A scrolled Space Bar's drop targets sit on their items")
    func hitFramesStayOnTheirItems() throws {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: 60)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        overlay.scrollOffset = 400
        overlay.render(followingActive: false)
        let fades = try #require(overlay.scrollGeom).fades
        try #require(fades.leading > 0, "nothing hidden at the start")
        let viewport = overlay.itemContainer.frame
        for (index, item) in overlay.itemViews.enumerated() {
            guard let space = SpaceID("\(index + 1)") as SpaceID?,
                let hit = overlay.hitFrames.first(where: {
                    $0.space == space
                })
            else { continue }
            let drawn = item.frame.offsetBy(
                dx: viewport.minX,
                dy: viewport.minY
            )
            #expect(
                drawn.contains(CGPoint(x: hit.frame.midX, y: hit.frame.midY)),
                Comment(
                    rawValue: "Space \(index + 1): \(hit.frame) vs \(drawn)"
                )
            )
        }
    }
}
