import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A section keeps its active entry in view and clear of the
/// fades, and a MANUAL scroll holds until the active entry
/// changes (#1517 review).
@Suite("Shelf follow and hold")
@MainActor
struct ShelfFollowTests {
    init() { LiquidGlassGate.override = { false } }

    /// Sixty Spaces, the `active`-th one active.
    private static func bar(active: Int) -> SpaceBarManager.Bar {
        var bar = paintedSpaceBar(front: nil, spaces: 60)
        let items = bar.items.enumerated().map { index, item in
            SpaceBarOverlay.Item(
                space: item.space ?? SpaceID("\(index + 1)"),
                spaceGlyph: item.spaceGlyph,
                apps: item.apps,
                active: index + 1 == active,
                overflow: item.overflow,
                focusInOverflow: item.focusInOverflow
            )
        }
        bar = SpaceBarManager.Bar(
            display: bar.display,
            items: items,
            frontApp: bar.frontApp,
            frontWindow: bar.frontWindow,
            strip: bar.strip,
            style: bar.style,
            stateMarkColors: bar.stateMarkColors
        )
        return bar
    }

    private func activeFrame(
        _ overlay: SpaceBarOverlay,
        active: Int
    ) -> CGRect {
        overlay.itemViews[active - 1].frame
    }

    @Test("The followed Space sits clear of the fades")
    func followClearsTheFades() throws {
        let manager = SpaceBarManager()
        manager.sync([Self.bar(active: 40)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let fades = try #require(overlay.scrollGeom).fades
        let frame = activeFrame(overlay, active: 40)
        let viewport = overlay.itemContainer.bounds
        #expect(frame.minX >= fades.leading)
        #expect(frame.maxX <= viewport.width - fades.trailing)
    }

    @Test("A page holds through a refresh, until the active changes")
    func pageHolds() throws {
        let manager = SpaceBarManager()
        manager.sync([Self.bar(active: 1)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        overlay.forwardCount.onPage()
        let paged = overlay.scrollOffset
        try #require(paged > 0, "the page moved nothing")
        // An unrelated refresh keeps the page.
        manager.sync([Self.bar(active: 1)])
        #expect(overlay.scrollOffset == paged)
        // A new active Space follows again.
        manager.sync([Self.bar(active: 2)])
        #expect(overlay.scrollOffset < paged)
    }

    /// Without a manual scroll every render follows: a strip that
    /// shrinks under the active Space brings it back into view.
    @Test("Without a page, a shrinking section still follows")
    func noPageNoHold() throws {
        let manager = SpaceBarManager()
        manager.sync([Self.bar(active: 30)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        var narrow = Self.bar(active: 30)
        var strip = narrow.strip
        strip.size.width /= 3
        narrow = SpaceBarManager.Bar(
            display: narrow.display,
            items: narrow.items,
            frontApp: narrow.frontApp,
            frontWindow: narrow.frontWindow,
            strip: strip,
            style: narrow.style,
            stateMarkColors: narrow.stateMarkColors
        )
        manager.sync([narrow])
        let frame = activeFrame(overlay, active: 30)
        let viewport = overlay.itemContainer.bounds
        #expect(frame.minX >= 0 && frame.maxX <= viewport.width)
    }

    @Test("The shelf lays nothing out while updateBars syncs")
    func relayoutHeld() throws {
        let spaces = SpaceBarManager()
        spaces.sync([Self.bar(active: 1)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        let shelves = ShelfManager()
        shelves.holdsRelayout = true
        shelves.sync([
            .init(
                display: barTitleDisplay,
                strip: barTitleStrip,
                shelf: KiwiShelf(),
                space: (section, barTitleStrip),
                app: nil
            )
        ])
        #expect(shelves.overlayForTesting(barTitleDisplay) == nil)
        shelves.holdsRelayout = false
        shelves.relayout(barTitleDisplay)
        #expect(shelves.overlayForTesting(barTitleDisplay) != nil)
    }
}
