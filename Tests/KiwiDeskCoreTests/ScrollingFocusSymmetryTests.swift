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

/// Drives the offset like a real retile loop: each call carries
/// the previous call's resulting offset forward as
/// `context.scrollOffset`, exactly as `KiwiCore.persistScrollOffset`
/// does between retiles. Reads `viewportOffset` (the ideal,
/// persisted value) rather than deriving it from a frame — far
/// slots pin at the screen edges (#139/#142), so frames no
/// longer expose the raw offset.
private func offsets(
    anchor: ScrollingParams.Anchor,
    focusSequence: [WindowID]
) -> [CGFloat] {
    var previous: CGFloat?
    var result: [CGFloat] = []
    for focused in focusSequence {
        var context = makeContext(anchor: anchor, focused: focused)
        context.scrollOffset = previous
        let offset = ScrollingLayout.viewportOffset(
            for: windows,
            in: context
        )
        result.append(offset)
        previous = offset
    }
    return result
}

/// Regression coverage for #66: focus-up must scroll the viewport
/// to reveal an off-screen window, mirroring focus-down — never
/// freeze the viewport and let the focused slot merely slide
/// within it (the overlay symptom). Scroll-into-view is *weakly*
/// symmetric: both directions pan monotonically and keep the
/// focused window fully visible, but a window is revealed at the
/// trailing edge going down and the leading edge going up, so the
/// two offset sequences are not identical reverses — asserting
/// that would pin behavior no edge anchor can satisfy without
/// reintroducing the freeze. Pinned for all three anchors since
/// the bug was an anchor-pin/boundary-clamp interaction.
@Suite("Scrolling focus up/down symmetry (#66)")
struct ScrollingFocusSymmetryTests {
    @Test(
        "Focus down then up both pan monotonically end to end",
        arguments: [
            ScrollingParams.Anchor.center,
            .left,
            .right,
        ]
    )
    func bothDirectionsPanMonotonically(
        anchor: ScrollingParams.Anchor
    ) throws {
        let down = offsets(
            anchor: anchor,
            focusSequence: [w1, w2, w3, w4, w5]
        )
        let up = offsets(
            anchor: anchor,
            focusSequence: [w5, w4, w3, w2, w1]
        )
        // Down never scrolls backward; up never scrolls forward.
        #expect(zip(down, down.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(zip(up, up.dropFirst()).allSatisfy { $0 <= $1 })
        // Both traverse the full range — focus-up is not frozen at
        // the far end (the bug); it pans all the way back to start.
        #expect(down.first == 0 && down.last == -1000)
        #expect(up.first == -1000 && up.last == 0)
    }

    @Test(
        "Focus-up reveals an off-screen window at the far end",
        arguments: [
            ScrollingParams.Anchor.center,
            .left,
            .right,
        ]
    )
    func focusUpRevealsOffscreen(
        anchor: ScrollingParams.Anchor
    ) throws {
        let layout = ScrollingLayout()
        // Scroll all the way down (focus w5 -> offset -1000).
        var previous: CGFloat?
        for focused in [w1, w2, w3, w4, w5] {
            var context = makeContext(
                anchor: anchor,
                focused: focused
            )
            context.scrollOffset = previous
            previous = ScrollingLayout.viewportOffset(
                for: windows,
                in: context
            )
        }
        let atEnd = try #require(previous)

        // w3 is clipped at the far end; focusing it must pan up
        // (not freeze while the slot slides within a static frame,
        // the #66 overlay symptom).
        var context = makeContext(anchor: anchor, focused: w3)
        context.scrollOffset = atEnd
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let after = ScrollingLayout.viewportOffset(
            for: windows,
            in: context
        )
        #expect(after > atEnd)

        // And the newly focused window must be fully in view.
        let f = try #require(frames[w3])
        #expect(f.minX >= context.usable.minX - 0.01)
        #expect(f.maxX <= context.usable.maxX + 0.01)
    }

    @Test("An already-visible focus does not move the viewport")
    func noGratuitousScroll() throws {
        // A viewport wide enough to hold a full neighbor (three
        // 400pt slots in 1400pt), unlike the tight two-slot
        // context above: focusing an already-visible window then
        // pans by the minimal amount — here, zero.
        let layout = ScrollingLayout()
        var context = makeContext(anchor: .center, focused: w2)
        context.bounds =
            CGRect(x: 0, y: 0, width: 1420, height: 1080)
        let seedFrames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let seed = ScrollingLayout.viewportOffset(
            for: windows,
            in: context
        )

        // Precondition: w3 is already fully visible at the seed.
        let w3Seed = try #require(seedFrames[w3])
        #expect(w3Seed.minX >= context.usable.minX - 0.01)
        #expect(w3Seed.maxX <= context.usable.maxX + 0.01)

        // Focusing it must not pan the viewport.
        context.focused = w3
        context.scrollOffset = seed
        let offset = ScrollingLayout.viewportOffset(
            for: windows,
            in: context
        )
        #expect(offset == seed)
    }
}
