import AppKit
import Testing

@testable import KiwiDeskCore

/// A wheel or trackpad scrolls a shelf section (#1517): the event
/// bubbles from the item under the pointer to the section root,
/// moves the offset while entries are hidden, holds like a page,
/// and passes on when nothing is hidden.
@Suite("Shelf scroll wiring")
@MainActor
struct ShelfScrollWiringTests {
    init() { LiquidGlassGate.override = { false } }

    /// A real scroll event, as a mouse wheel reports `lines`
    /// notches down (negative) or up.
    private func wheel(_ lines: Int32) throws -> NSEvent {
        let cg = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 1,
                wheel1: lines,
                wheel2: 0,
                wheel3: 0
            )
        )
        return try #require(NSEvent(cgEvent: cg))
    }

    @Test("A wheel over a Space scrolls the Space Bar and holds")
    func spaceBarWheel() throws {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: 60)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(overlay.scrollOffset == 0)
        let item = try #require(overlay.itemViews.first)
        item.scrollWheel(with: try wheel(-3))
        let scrolled = overlay.scrollOffset
        #expect(scrolled > 0)
        // A refresh keeps the scroll, as it keeps a page.
        manager.sync([paintedSpaceBar(front: nil, spaces: 60)])
        #expect(overlay.scrollOffset == scrolled)
        // Back up past the start: clamped, never negative.
        item.scrollWheel(with: try wheel(40))
        #expect(overlay.scrollOffset == 0)
    }

    @Test("A wheel over a window scrolls the App Bar and holds")
    func appBarWheel() throws {
        let manager = AppBarManager()
        let bar = paintedAppBar(
            items: (1...60).map { appBarItem(UInt32($0), text: "W\($0)") }
        )
        manager.sync([bar])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(overlay.scrollOffset == 0)
        let item = try #require(overlay.itemViews.first)
        item.scrollWheel(with: try wheel(-3))
        let scrolled = overlay.scrollOffset
        #expect(scrolled > 0)
        manager.sync([bar])
        #expect(overlay.scrollOffset == scrolled)
    }

    /// Nothing hidden, nothing taken: the section declines, so a
    /// scroll over a short bar is not recorded as a manual one.
    @Test("A section with nothing hidden declines the scroll")
    func shortBarDeclines() throws {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: 3)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let delta = ShelfScrollInput.Delta(x: 0, y: -3, precise: false)
        #expect(!overlay.root.onScroll(delta))
        #expect(overlay.scrollOffset == 0)
    }
}
