import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)
private let w5 = WindowID(5)
private let windows = [w1, w2, w3, w4, w5]

/// A 1000pt usable width, 400pt slots, no gap: five slots
/// overflow to a 2000pt row, giving a clean ±1000pt scroll range
/// with round numbers at every step.
private func makeContext(
    anchor: ScrollingParams.Anchor,
    focused: WindowID?
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1020, height: 1080),
        gaps: .uniform(10),
        focused: focused
    )
    context.scrolling.appBar.enabled = false
    context.scrolling.slotSize = .points(400)
    context.gaps.inner.horizontal = 0
    context.scrolling.anchor = anchor
    return context
}

/// Drives `calculateGeometry` like a real retile loop: each call
/// carries the previous call's resulting offset forward as
/// `context.scrollOffset`, exactly as `KiwiCore.persistScrollOffset`
/// does between retiles.
private func offsets(
    anchor: ScrollingParams.Anchor,
    focusSequence: [WindowID]
) -> [CGFloat] {
    let layout = ScrollingLayout()
    var previous: CGFloat?
    var result: [CGFloat] = []
    for focused in focusSequence {
        var context = makeContext(anchor: anchor, focused: focused)
        context.scrollOffset = previous
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let offset =
            frames[w1]!.minX - context.usable.minX
        result.append(offset)
        previous = offset
    }
    return result
}

/// Regression coverage for #66: focus-up must scroll the
/// viewport by the same amounts focus-down did, never overlay
/// (freeze the viewport and let the focused slot merely slide
/// within it). Pinned for all three anchors since the bug was an
/// anchor-pin/boundary-clamp interaction, not anchor-specific.
@Suite("Scrolling focus up/down symmetry (#66)")
struct ScrollingFocusSymmetryTests {
    @Test(
        "Stepping focus back up retraces the down sequence",
        arguments: [
            ScrollingParams.Anchor.center,
            .left,
            .right,
        ]
    )
    func upMirrorsDown(anchor: ScrollingParams.Anchor) throws {
        let down = offsets(
            anchor: anchor,
            focusSequence: [w1, w2, w3, w4, w5]
        )
        let up = offsets(
            anchor: anchor,
            focusSequence: [w5, w4, w3, w2, w1]
        )
        // Stepping down 0->4 then up 4->0 must retrace the same
        // viewport positions in reverse — the exact symmetry the
        // #66 bug broke for edge anchors.
        #expect(down == up.reversed())
    }

    @Test(
        "Focus-up scrolls when the viewport is at the far end",
        arguments: [
            ScrollingParams.Anchor.center,
            .left,
            .right,
        ]
    )
    func focusUpScrollsAtBoundary(
        anchor: ScrollingParams.Anchor
    ) throws {
        let layout = ScrollingLayout()

        // Reach the far end first (focus w5), exactly as a user
        // scrolling all the way down would.
        var previous: CGFloat?
        for focused in [w1, w2, w3, w4, w5] {
            var context = makeContext(
                anchor: anchor,
                focused: focused
            )
            context.scrollOffset = previous
            let frames = layout.calculateGeometry(
                for: windows,
                in: context
            )
            previous = frames[w1]!.minX - context.usable.minX
        }
        let atEnd = try #require(previous)

        // Step focus up one slot (w5 -> w4): before the fix this
        // could leave the viewport frozen at the boundary while
        // w4 merely slid into view of an unmoving frame (the
        // overlay symptom). The viewport must actually pan.
        var context = makeContext(anchor: anchor, focused: w4)
        context.scrollOffset = atEnd
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let afterStepUp =
            frames[w1]!.minX - context.usable.minX
        #expect(afterStepUp != atEnd)

        // And the newly focused window must be fully in view,
        // not clipped by the still-pinned edge.
        let focusedFrame = try #require(frames[w4])
        #expect(focusedFrame.minX >= context.usable.minX - 0.01)
        #expect(focusedFrame.maxX <= context.usable.maxX + 0.01)
    }

    @Test("An already-visible focus does not move the viewport")
    func noGratuitousScroll() throws {
        // Center anchor's first scroll (nil previous) puts w3 at
        // the exact viewport center. w2 and w4 are then already
        // fully visible neighbors — focusing them should not
        // recenter, only the minimal (here: zero) pan.
        let layout = ScrollingLayout()
        var context = makeContext(anchor: .center, focused: w3)
        let seedFrames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let seedOffset =
            seedFrames[w1]!.minX - context.usable.minX

        context.focused = w2
        context.scrollOffset = seedOffset
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let offset = frames[w1]!.minX - context.usable.minX
        #expect(offset == seedOffset)
    }
}
