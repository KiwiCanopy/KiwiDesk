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

/// A 1000pt usable width (1020 less the 10pt outer gaps), no
/// inner gap, so a 400pt slot puts window `i` at `(i-1) * 400`
/// and five of them overflow to a 2000pt row. Every number
/// below is read off that pinned geometry (#531).
private func makeContext(
    anchor: ScrollingParams.Anchor = .follow,
    focused: WindowID?,
    slot: CGFloat
) -> LayoutContext {
    var context = LayoutContext(
        bounds: CGRect(x: 0, y: 0, width: 1020, height: 1080),
        gaps: .uniform(10),
        focused: focused
    )
    context.scrolling.appBar.enabled = false
    context.scrolling.slotSize = .points(slot)
    context.gaps.inner.horizontal = 0
    context.scrolling.anchor = anchor
    // Pin the floor the slot resolution reasons from (#660):
    // every coordinate below assumes the asked slot survives
    // `max(resolved, minWindowSize)` in `ScrollingLayout.metrics`.
    context.minWindowSize = 300
    return context
}

/// How far into the viewport a window's leading edge sits.
private func lead(
    of window: WindowID,
    in frames: [WindowID: CGRect],
    _ context: LayoutContext
) throws -> CGFloat {
    try #require(frames[window]).minX - context.usable.minX
}

/// Resizing a scrolling slot re-anchors the viewport (#966).
///
/// One slot size serves the whole row, so a resize moves every
/// slot's POSITION along it — and `follow`, which holds the
/// prior offset by design (#66), was left holding a number that
/// now pointed somewhere else: the focused window slid toward
/// the leading edge, as if the resize had been a scroll nobody
/// asked for.
///
/// The fix is a discrimination, so these pin both sides of it:
/// the row moving underneath an unchanged focus re-anchors, a
/// focus change still pans minimally from the offset it had.
@Suite("Scrolling resize re-anchors the viewport (#966)")
struct ScrollingResizeAnchorTests {
    let layout = ScrollingLayout()

    @Test("A slot shrink leaves the focused window in place")
    func shrinkKeepsFocusedWindowInPlace() throws {
        // w3 toward the right of the visible run with w1 half
        // shown behind it — the reported repro's shape — but
        // NOT touching the trailing border: 500 + 400 leaves
        // 100pt of w4 showing. A slot resting ON a border is
        // the other rule (`shrinkHoldsTheTrailingBorder`), and
        // this fixture was that case until the border rule
        // landed, which is why it is spelled out here.
        var context = makeContext(focused: w3, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -300,
            focus: w3,
            position: 800
        )
        let before = try lead(
            of: w3,
            in: layout.calculateGeometry(
                for: windows,
                in: context
            ),
            context
        )

        context.scrolling.slotSize = .points(350)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        // The window the user is resizing holds its place and
        // the row contracts around it. Both clamps sit clear of
        // this — the row is still 1750pt against a 1000pt
        // viewport — so `rowEndOutranksTheReAnchor` below is
        // where they get to disagree.
        #expect(try lead(of: w3, in: frames, context) == before)
        #expect(
            ScrollingLayout.viewportRest(
                for: windows,
                in: context
            ).offset == -200
        )
    }

    @Test("A shrink off a border gives its space to the open side")
    func shrinkHoldsTheTrailingBorder() throws {
        // w3 resting flush against the trailing border with a
        // hidden w2 behind it (device QA, 2026-08-27). Holding
        // its leading edge would tear it off the border and open
        // a gap the row then fills from behind; the border is
        // what it keeps, so the space comes off the open side
        // and more of w2 shows.
        var context = makeContext(focused: w3, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -200,
            focus: w3,
            position: 800,
            restingOn: .trailing
        )
        context.scrolling.slotSize = .points(350)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let focused = try #require(frames[w3])
        #expect(
            abs(focused.maxX - context.usable.maxX) < 0.01
        )
        #expect(try lead(of: w3, in: frames, context) == 650)
    }

    @Test("The row end outranks the re-anchor")
    func rowEndOutranksTheReAnchor() throws {
        // w4, NOT the last slot: a last slot at a legal offset is
        // flush-trailing by construction (the boundary clamp
        // forces `lead + span == along` for it), so seating this
        // there let the border arm return the clamp's own answer
        // and the test stopped watching the clamp at all
        // (code-reviewer, 2026-08-27).
        //
        // Slots shrink 400 → 300 (the #660 floor is 300, so a
        // smaller ask would resolve back up to it and land the
        // held base exactly ON the boundary — a no-op clamp, the
        // same trap one step over). The row becomes 1500 in a
        // 1000pt viewport: holding w4's place would need -600
        // and reveal 100pt of margin past the row end, so the
        // clamp stops it at -500.
        var context = makeContext(focused: w4, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -900,
            focus: w4,
            position: 1200
        )
        context.scrolling.slotSize = .points(300)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w4, in: frames, context) == 400)
        let last = try #require(frames[w5])
        #expect(abs(last.maxX - context.usable.maxX) < 0.01)
    }

    @Test("The rest records which border the slot rested on")
    func viewportRestRecordsTheBorder() throws {
        // The producer half, and the ONLY net on it: every test
        // above builds its rest by hand, so a `viewportRest`
        // that recorded the wrong verdict would leave all of
        // them green while the border rule was dead in
        // production (guard-prover, 2026-08-27 — recording a
        // constant there passed all 4088 tests).
        //
        // Each case derives its expectation from the fixture's
        // own geometry rather than from what the engine just
        // wrote, which is what makes it a reading rather than
        // an echo.
        var context = makeContext(focused: w3, slot: 400)

        // w3 at position 800, offset -200 → lead 600, and
        // 600 + 400 == the 1000pt viewport: on the trailing
        // border.
        context.scrollRest = ScrollRest(offset: -200)
        #expect(
            ScrollingLayout.viewportRest(
                for: windows,
                in: context
            ).slot?.restingOn == .trailing
        )

        context.focused = w1
        context.scrollRest = ScrollRest(offset: 0)
        // w1 at position 0 with the viewport at 0: leading.
        #expect(
            ScrollingLayout.viewportRest(
                for: windows,
                in: context
            ).slot?.restingOn == .leading
        )

        // A slot as wide as the viewport is flush at BOTH, and
        // the leading edge is the recorded verdict — the
        // precedence lives here, not in the consumer.
        context.scrolling.slotSize = .points(1000)
        context.focused = w2
        context.scrollRest = ScrollRest(offset: -1010)
        #expect(
            ScrollingLayout.viewportRest(
                for: windows,
                in: context
            ).slot?.restingOn == .leading
        )
    }

    @Test("A window closing ahead of the focus re-anchors too")
    func removalAheadOfTheFocusReAnchors() throws {
        // A resize is not the only thing that moves every slot
        // underneath an unchanged focus. w1 leaving the row
        // pulls w4 back by one slot; the viewport follows so
        // the window nobody touched stays where the user left
        // it.
        var context = makeContext(focused: w4, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -800,
            focus: w4,
            position: 1200
        )
        let frames = layout.calculateGeometry(
            for: [w2, w3, w4, w5],
            in: context
        )
        #expect(try lead(of: w4, in: frames, context) == 400)
    }
}
