import AppKit
import Testing

@testable import KiwiDeskCore

/// Overflow shows as fades and counts, never arrows (#1517).
@Suite("Shelf counts and fades")
@MainActor
struct ShelfCountTests {
    init() { LiquidGlassGate.override = { false } }

    @Test("A count keeps its chevron, pointing where the entries are")
    func countText() {
        #expect(
            ShelfCountView.text(count: 3, side: .before, horizontal: true)
                == "‹3"
        )
        #expect(
            ShelfCountView.text(count: 4, side: .after, horizontal: true)
                == "4›"
        )
        #expect(
            ShelfCountView.text(count: 2, side: .before, horizontal: false)
                == "˄2"
        )
        #expect(
            ShelfCountView.text(count: 2, side: .after, horizontal: false)
                == "2˅"
        )
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
