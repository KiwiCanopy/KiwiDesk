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

/// Scrolling's horizontal mechanics. The focus anchor is applied
/// on every focus (#239): `center`/`start`/`end` rest the focused
/// slot at a fixed position, while `follow` (the default) pans the
/// minimal amount needed to keep it visible (#66) — see
/// `ScrollingFocusSymmetryTests` for the up/down regression
/// coverage.
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

    @Test("Center anchor centers the focused column")
    func centerAnchor() throws {
        var context = makeContext(focused: w2)
        context.scrolling.anchor = .center
        context.scrolling.slotSize = .points(800)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let focused = try #require(frames[w2])
        #expect(abs(focused.midX - context.usable.midX) < 0.01)
        #expect(focused.width == 800)
    }

    @Test("A fixed anchor re-seats an already-visible focus (#239)")
    func fixedAnchorReseatsVisibleFocus() throws {
        // The crux of #239: `center` recomputes the resting
        // position on every focus. Even with a carried-forward
        // offset at which the focus is already fully visible (the
        // old first-placement-only seed would have held it), the
        // viewport pans to re-center — it is not `follow`.
        var context = makeContext(focused: w3)
        context.scrolling.appBar.enabled = false
        context.scrolling.anchor = .center
        context.scrolling.slotSize = .points(400)
        context.bounds = CGRect(x: 0, y: 0, width: 1420, height: 1080)
        // w3 is fully visible at this prior offset, but off-center.
        context.scrollOffset = -180
        let windows = [w1, w2, w3, w4, w5]
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let offset = ScrollingLayout.viewportOffset(
            for: windows,
            in: context
        )
        let focused = try #require(frames[w3])
        #expect(abs(focused.midX - context.usable.midX) < 0.01)
        #expect(offset != -180)
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

    @Test("A slot never tiles below minWindowSize")
    func slotHonorsMinWindowSize() throws {
        // 5% of a 1000-pt axis is ~49 pt — well under the 300-pt
        // floor, so the column falls back to minWindowSize.
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
            focused: w1
        )
        context.scrolling.appBar.enabled = false
        context.minWindowSize = 300
        context.scrolling.slotSize = .fraction(0.05)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        #expect(try #require(frames[w1]).width == 300)
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

    /// 1000pt usable width, 400pt slots, no gap — the symmetry
    /// suite's round-number geometry (#142 edge pins).
    private func pinContext(focused: WindowID) -> LayoutContext {
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 1020, height: 1080),
            focused: focused
        )
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(400)
        context.gaps.inner.horizontal = 0
        return context
    }

    @Test("Slots far past the left edge pin at a sliver (#142)")
    func farLeftSlotsPin() throws {
        var context = pinContext(focused: w5)
        context.scrollOffset = -1000
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: context
        )
        // w1/w2 are fully off-left ideally; both keep an
        // edgePeek sliver so macOS can actually apply them.
        let peek = ScrollingLayout.edgePeek
        #expect(
            try #require(frames[w1]).maxX
                == context.usable.minX + peek
        )
        #expect(
            try #require(frames[w2]).maxX
                == context.usable.minX + peek
        )
        // The focused slot is untouched: exactly flush at the
        // trailing edge (an inward displacement would still
        // satisfy a <= check, so assert equality).
        let focused = try #require(frames[w5])
        #expect(focused.maxX == context.usable.maxX)
    }

    @Test("Slots far past the right edge pin at a sliver (#142)")
    func farRightSlotsPin() throws {
        var context = pinContext(focused: w1)
        context.scrollOffset = 0
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: context
        )
        let peek = ScrollingLayout.edgePeek
        #expect(
            try #require(frames[w4]).minX
                == context.usable.maxX - peek
        )
        #expect(
            try #require(frames[w5]).minX
                == context.usable.maxX - peek
        )
        // A merely partially visible slot is NOT pinned.
        #expect(
            try #require(frames[w3]).minX
                == context.usable.minX + 800
        )
        // The focused slot sits exactly at the leading edge —
        // a sign error in the leading floor would move it.
        #expect(
            try #require(frames[w1]).minX == context.usable.minX
        )
    }

    @Test("A slot smaller than edgePeek never displaces focus")
    func tinySlotsKeepFocusedAtEdge() throws {
        // `.fraction` can resolve below `edgePeek` (its 5%
        // floor has no point minimum): 5% of 880pt = 44pt. The
        // peek caps at the slot size, so the trailing pin must
        // not pull the fully visible focused slot inward.
        let many = (1...20).map { WindowID(UInt32($0)) }
        var context = makeContext(
            bounds: CGRect(x: 0, y: 0, width: 900, height: 1080),
            focused: many[19]
        )
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .fraction(0.05)
        let frames = layout.calculateGeometry(
            for: many,
            in: context
        )
        let focused = try #require(frames[many[19]])
        #expect(abs(focused.maxX - context.usable.maxX) < 0.01)
    }

    @Test("viewportOffset matches frames when no pin engages")
    func viewportOffsetFrameParity() throws {
        // Guards the in-file mirror between `viewportOffset`
        // and `calculateGeometry`: with three slots nothing
        // scrolls far enough to pin, so the frame-derived
        // offset must equal the ideal one exactly.
        let context = pinContext(focused: w2)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let ideal = ScrollingLayout.viewportOffset(
            for: [w1, w2, w3],
            in: context
        )
        let fromFrame =
            try #require(frames[w1]).minX - context.usable.minX
        #expect(fromFrame == ideal)
    }
}
