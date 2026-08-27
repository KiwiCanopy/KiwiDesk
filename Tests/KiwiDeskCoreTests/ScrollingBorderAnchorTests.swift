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

/// The border half of the #966 re-anchor: a slot resting ON a
/// viewport border keeps that border across a resize instead of
/// its leading edge, and the verdict is reached where the offset
/// is MEASURED rather than re-derived later.
///
/// Split from `ScrollingResizeAnchorTests` at the file ceiling.
/// Its own fixture is a copy by convention (tests.md ▸ per-file
/// private helpers), and pins the same geometry (#531/#660).
@Suite("Scrolling border anchoring (#966)")
struct ScrollingBorderAnchorTests {
    let layout = ScrollingLayout()

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

    @Test("Flushness absorbs rounding, not a visible gap")
    func borderToleranceAbsorbsRoundingOnly() throws {
        // `edgeTolerance` exists so accumulated float rounding
        // does not stop a flush slot reading as flush, and its
        // docstring says a slot a VISIBLE distance away must
        // not. Nothing pinned either half: the constant passed
        // the whole suite at 0 AND at 99 (guard-prover, twice).
        // These pin the purpose from both sides — the value can
        // move, the two verdicts cannot swap.
        let span: CGFloat = 400
        let along: CGFloat = 1000

        // A fifth of a point short of the trailing border is
        // rounding, and still rests on it.
        #expect(
            ScrollingLayout.border(
                lead: along - span - 0.2,
                span: span,
                along: along
            ) == .trailing
        )
        // Five points short is a gap you can see; re-anchoring
        // to the border would visibly jump the slot there.
        #expect(
            ScrollingLayout.border(
                lead: along - span - 5,
                span: span,
                along: along
            ) == nil
        )
        // The same both ways at the leading border.
        #expect(
            ScrollingLayout.border(
                lead: 0.2,
                span: span,
                along: along
            ) == .leading
        )
        #expect(
            ScrollingLayout.border(
                lead: 5,
                span: span,
                along: along
            ) == nil
        )
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

}
