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
    LayoutContext(bounds: bounds, gaps: gaps, focused: focused)
}

/// Vertical mirrors the horizontal mechanics onto the y axis; the
/// bar (default on) resolves to the left edge, carving width, so
/// top/bottom snapping is against the full usable height. (Row
/// stacking + strip carving live in AppBarTests.)
@Suite("Scrolling layout (vertical)")
struct ScrollingVerticalTests {
    let layout = ScrollingLayout()

    @Test("Focused row is centered on first scroll")
    func verticalCenterAnchor() throws {
        // 400×3 + gaps overflows the ~1060pt usable height, so the
        // viewport scrolls and centers the focus (a fitting row
        // would top-align at offset 0 instead). No previous
        // offset: the anchor seeds the position.
        var context = makeContext(focused: w2)
        context.scrolling.orientation = .vertical
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
        let bottomFrames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let bottomOffset =
            try #require(bottomFrames[w1]).minY
            - context.usable.minY

        // Focus the top row (off-screen at the bottom), carrying
        // the previous offset forward as a real retile would.
        context.focused = w1
        context.scrollOffset = bottomOffset
        let topFrames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let topOffset =
            try #require(topFrames[w1]).minY - context.usable.minY

        // The viewport must pan up to reveal it (not freeze at the
        // bottom boundary while the row slides within a static
        // viewport — the #66 overlay symptom).
        #expect(topOffset > bottomOffset)
        // And the newly focused row must be fully in view.
        let w1Frame = try #require(topFrames[w1])
        #expect(w1Frame.minY >= context.usable.minY - 0.01)
        #expect(w1Frame.maxY <= context.usable.maxY + 0.01)
    }
}
