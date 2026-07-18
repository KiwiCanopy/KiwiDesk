import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    gaps: Gaps = .uniform(10),
    focused: WindowID? = nil
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: gaps,
        focused: focused
    )
    // Bar on the left (edge is absolute since #293), carving
    // width, so top/bottom snapping is against the full usable
    // height.
    context.scrolling.appBar.edge = .left
    return context
}

/// Vertical mirrors the horizontal mechanics onto the y axis;
/// the suite pins its bar to the left edge, carving width, so
/// top/bottom snapping is against the full usable height. (Row
/// stacking + strip carving live in AppBarTests.)
@Suite("Scrolling layout (vertical)")
struct ScrollingVerticalTests {
    let layout = ScrollingLayout()

    @Test("Center anchor centers the focused row")
    func verticalCenterAnchor() throws {
        // 400×3 + gaps overflows the ~1060pt usable height, so the
        // viewport scrolls and centers the focus (a fitting row
        // would top-align at offset 0 instead).
        var context = makeContext(focused: w2)
        context.scrolling.orientation = .vertical
        context.scrolling.anchor = .center
        context.scrolling.slotSize = .points(400)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let focused = try #require(frames[w2])
        #expect(abs(focused.midY - context.usable.midY) < 0.01)
        #expect(focused.height == 400)
    }

    @Test("First row snaps to the top edge on first scroll")
    func verticalTopBoundary() throws {
        var context = makeContext(focused: w1)
        context.scrolling.orientation = .vertical
        context.scrolling.slotSize = .points(300)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let first = try #require(frames[w1])
        #expect(first.minY == context.usable.minY)
    }

    @Test("Last row snaps to the bottom edge on first scroll")
    func verticalBottomBoundary() throws {
        var context = makeContext(focused: w3)
        context.scrolling.orientation = .vertical
        context.scrolling.slotSize = .points(400)
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let last = try #require(frames[w3])
        #expect(abs(last.maxY - context.usable.maxY) < 0.01)
    }

    @Test("Short column top-aligns without margins")
    func verticalShortColumn() throws {
        var context = makeContext(focused: w2)
        context.scrolling.orientation = .vertical
        context.scrolling.slotSize = .points(200)
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: context
        )
        let first = try #require(frames[w1])
        #expect(first.minY == context.usable.minY)
    }

    @Test("Focus-up scrolls the viewport up (#66)")
    func verticalFocusUpScrolls() throws {
        // Enough rows to overflow, focused at the far (bottom)
        // end so the viewport is scrolled all the way down.
        var context = makeContext(focused: w3)
        context.scrolling.orientation = .vertical
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(400)
        // Read offsets the way `persistScrollOffset` does: a
        // pinned row's frame no longer exposes the raw offset.
        let bottomOffset = ScrollingLayout.viewportOffset(
            for: [w1, w2, w3],
            in: context
        )

        // Focus the top row (off-screen at the top), carrying
        // the previous offset forward as a real retile would.
        context.focused = w1
        context.scrollOffset = bottomOffset
        let topFrames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let topOffset = ScrollingLayout.viewportOffset(
            for: [w1, w2, w3],
            in: context
        )

        // The viewport must pan up to reveal it (not freeze at the
        // bottom boundary while the row slides within a static
        // viewport — the #66 overlay symptom).
        #expect(topOffset > bottomOffset)
        // And the newly focused row must be fully in view.
        let w1Frame = try #require(topFrames[w1])
        #expect(w1Frame.minY >= context.usable.minY - 0.01)
        #expect(w1Frame.maxY <= context.usable.maxY + 0.01)
    }

    @Test("Up-overflow rows pin at the top border")
    func verticalUpOverflowPins() throws {
        // Focus-down from w1: the outgoing row's ideal frame
        // straddles the top border, which macOS refuses to
        // place — it pins at the edge instead, full-size, so
        // its upper strip peeks above the focused row.
        var context = makeContext(focused: w2)
        context.scrolling.orientation = .vertical
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(800)
        context.scrollOffset = 0
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let pinned = try #require(frames[w1])
        #expect(pinned.minY == context.usable.minY)
        #expect(pinned.height == 800)
        // The focused row is fully visible at the bottom edge.
        let focused = try #require(frames[w2])
        #expect(abs(focused.maxY - context.usable.maxY) < 0.01)
    }

    @Test("Rows scrolled fully past the top pin too")
    func verticalFarOverflowPins() throws {
        // Two steps down: w1's ideal frame lies entirely above
        // the screen. There is no "further up" on macOS, so it
        // pins at the border just like a straddling row.
        var context = makeContext(focused: w3)
        context.scrolling.orientation = .vertical
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(800)
        context.scrollOffset = -550
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let first = try #require(frames[w1])
        let second = try #require(frames[w2])
        #expect(first.minY == context.usable.minY)
        #expect(second.minY == context.usable.minY)
        // The focused row still lands fully in view.
        let focused = try #require(frames[w3])
        #expect(focused.minY >= context.usable.minY - 0.01)
        #expect(focused.maxY <= context.usable.maxY + 0.01)
    }

    @Test("Rows far past the bottom pin at a sliver (#142)")
    func farBottomRowsPin() throws {
        // Focus at the top: the third row lies fully below the
        // viewport ideally; it keeps an edgePeek sliver so the
        // frame stays applicable (macOS clamps fully offscreen
        // frames to its own minimum anyway).
        var context = makeContext(focused: w1)
        context.scrolling.orientation = .vertical
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(800)
        context.scrollOffset = 0
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let third = try #require(frames[w3])
        #expect(
            third.minY
                == context.usable.maxY - ScrollingLayout.edgePeek
        )
        // The partially visible second row is NOT pinned.
        let second = try #require(frames[w2])
        #expect(second.minY == context.usable.minY + 810)
    }
}
