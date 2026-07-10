import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)
private let w5 = WindowID(5)

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    gaps: Gaps = .uniform(10),
    focused: WindowID? = nil
) -> LayoutContext {
    LayoutContext(bounds: bounds, gaps: gaps, focused: focused)
}

/// Scrolling's horizontal mechanics. The anchor only seeds a
/// fresh scroll (`context.scrollOffset == nil`); once scrolled,
/// focus moves pan the minimal amount needed to keep the focused
/// slot fully visible (#66) — see `ScrollingFocusSymmetryTests`
/// for the up/down regression coverage.
@Suite("Scrolling layout")
struct ScrollingLayoutTests {
    let layout = ScrollingLayout()

    @Test("Single window scales to the full width")
    func singleWindow() throws {
        // Isolate the column mechanics from the now-default
        // app bar (its strip carving is covered separately).
        var context = makeContext()
        context.scrolling.appBar.enabled = false
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("Focused column is centered on first scroll")
    func centerAnchor() throws {
        // No previous offset: the anchor seeds the position.
        var context = makeContext(focused: w2)
        context.scrolling.slotSize = .points(800)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let focused = try #require(frames[w2])
        #expect(abs(focused.midX - context.usable.midX) < 0.01)
        #expect(focused.width == 800)
    }

    @Test("First column snaps to the left edge on first scroll")
    func leftBoundary() throws {
        let context = makeContext(focused: w1)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let first = try #require(frames[w1])
        #expect(first.minX == context.usable.minX)
    }

    @Test("Last column snaps to the right edge on first scroll")
    func rightBoundary() throws {
        let context = makeContext(focused: w3)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let last = try #require(frames[w3])
        #expect(abs(last.maxX - context.usable.maxX) < 0.01)
    }

    @Test("Columns keep fixed width and full height")
    func columnDimensions() throws {
        var context = makeContext(focused: w2)
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(800)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        for frame in frames.values {
            #expect(frame.width == 800)
            #expect(frame.height == context.usable.height)
        }
    }

    @Test("Short rows left-align without margins")
    func shortRow() throws {
        var context = makeContext(focused: w2)
        context.scrolling.slotSize = .points(400)
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let first = try #require(frames[w1])
        #expect(first.minX == context.usable.minX)
    }

    @Test("Auto slot size resolves to the orientation standard")
    func autoSlotSize() throws {
        // Horizontal auto → fixed 1100 pt column; vertical auto →
        // 80% of the *available* along-axis (height here).
        var horizontal = makeContext(focused: w1)
        horizontal.scrolling.appBar.enabled = false
        horizontal.scrolling.slotSize = .auto
        let hFrames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: horizontal
        )
        #expect(try #require(hFrames[w1]).width == 1100)

        var vertical = makeContext(focused: w1)
        vertical.scrolling.appBar.enabled = false
        vertical.scrolling.orientation = .vertical
        vertical.scrolling.slotSize = .auto
        let vFrames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: vertical
        )
        let expected = vertical.usable.height * 0.8
        #expect(
            abs(try #require(vFrames[w1]).height - expected) < 0.01
        )
    }

    @Test("Scrolling raise order math")
    func scrollingRaiseOrder() throws {
        let windows = [w1, w2, w3, w4, w5]

        // Focus is w1 (index 0)
        #expect(
            KiwiCore.scrollingRaiseOrder(windows, focusIndex: 0) == [
                w5, w4, w3, w2,
            ]
        )

        // Focus is w3 (index 2)
        #expect(
            KiwiCore.scrollingRaiseOrder(windows, focusIndex: 2) == [
                w1, w2, w5, w4,
            ]
        )

        // Focus is w5 (index 4)
        #expect(
            KiwiCore.scrollingRaiseOrder(windows, focusIndex: 4) == [
                w1, w2, w3, w4,
            ]
        )

        // Focus index out of bounds
        #expect(
            KiwiCore.scrollingRaiseOrder(windows, focusIndex: 10) == windows
        )
    }
}
