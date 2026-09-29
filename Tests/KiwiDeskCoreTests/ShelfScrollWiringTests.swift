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
    /// notches down (negative) or up — or, `precise`, a trackpad
    /// reporting that many points.
    private func wheel(
        _ lines: Int32,
        precise: Bool = false
    ) throws -> NSEvent {
        let cg = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: precise ? .pixel : .line,
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

    /// A wheel notch travels about an item, a trackpad exactly its
    /// points: the root hands `ShelfScrollInput` the event's own
    /// precision.
    @Test("A notch travels an item, a trackpad its points")
    func notchAndTrackpad() throws {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: 60)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let step = try #require(overlay.scrollGeom).step
        let item = try #require(overlay.itemViews.first)
        item.scrollWheel(with: try wheel(-1))
        #expect(abs(overlay.scrollOffset - step) < 0.01)
        item.scrollWheel(with: try wheel(-7, precise: true))
        #expect(
            abs(
                overlay.scrollOffset - step - 7 * ShelfScrollInput.trackpadGain
            ) < 0.01
        )
    }

    /// A parent that records the scrolls reaching it.
    private final class Spy: NSView {
        var scrolls = 0
        override func scrollWheel(with event: NSEvent) { scrolls += 1 }
    }

    /// A section with nothing hidden passes the event up the
    /// responder chain rather than swallowing it; one that takes it
    /// passes nothing.
    @Test("A declined scroll bubbles up; a taken one stops")
    func declinedScrollBubbles() throws {
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3)])
        let short = try #require(spaces.overlayForTesting(barTitleDisplay))
        let spy = Spy()
        spy.addSubview(short.root)
        short.root.scrollWheel(with: try wheel(-1))
        #expect(spy.scrolls == 1)
        spaces.sync([paintedSpaceBar(front: nil, spaces: 60)])
        short.root.scrollWheel(with: try wheel(-1))
        #expect(spy.scrolls == 1)
    }
}
