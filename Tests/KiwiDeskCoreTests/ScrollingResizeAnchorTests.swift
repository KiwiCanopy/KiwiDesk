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
            position: 800,
            span: 400
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
            span: 400
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

    @Test("Filling the viewport keeps the leading edge")
    func fillingTheViewportKeepsTheLeadingEdge() throws {
        // Flush at BOTH borders, so the trailing rule would have
        // a claim too — the leading edge wins, which is where
        // the eye is anchored and the only answer that does not
        // shift every line of text under the reader.
        var context = makeContext(focused: w2, slot: 1000)
        context.scrollRest = ScrollRest(
            offset: -1000,
            focus: w2,
            position: 1000,
            span: 1000
        )
        context.scrolling.slotSize = .points(700)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w2, in: frames, context) == 0)
    }

    @Test("A focus change still pans from the recorded offset")
    func focusChangePansFromTheOffset() throws {
        // The rest was measured against w3; focusing w2 is a
        // focus change, so the viewport holds its offset and
        // pans only if w2 would be clipped — it isn't, so it
        // does not move at all (#66). Re-anchoring here instead
        // would jump the row by a whole slot.
        var context = makeContext(focused: w3, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -200,
            focus: w3,
            position: 800,
            span: 400
        )
        context.focused = w2
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w2, in: frames, context) == 200)
        #expect(
            ScrollingLayout.viewportRest(
                for: windows,
                in: context
            ).offset == -200
        )
    }

    @Test("A rest with no recorded slot holds its offset")
    func restWithoutSlotHoldsItsOffset() throws {
        // Nothing says the offset and the row were measured
        // together — a hand-seeded rest, or one recorded on a
        // pass that placed no slot — so it reads as a focus
        // change, which is what every offset did before #966.
        var context = makeContext(focused: w3, slot: 350)
        context.scrollRest = ScrollRest(offset: -200)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w3, in: frames, context) == 500)
    }

    @Test("A fixed anchor re-seats the focus across a resize")
    func fixedAnchorReseatsAcrossAResize() throws {
        // The issue's own prediction: `center`/`start`/`end`
        // recompute a resting position on every call, so they
        // never read the recorded offset and cannot drift with
        // it. Seeded with a rest that would drift badly.
        var context = makeContext(
            anchor: .center,
            focused: w3,
            slot: 350
        )
        context.scrollRest = ScrollRest(
            offset: -200,
            focus: w3,
            position: 800,
            span: 400
        )
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        let focused = try #require(frames[w3])
        #expect(abs(focused.midX - context.usable.midX) < 0.01)
    }

    @Test("The row end outranks the re-anchor")
    func rowEndOutranksTheReAnchor() throws {
        // Holding w5's place would need offset -600, which shows
        // 100pt of empty margin past a row that shrank to 1500 in
        // a 1000pt viewport. The boundary clamp wins, so the
        // focus re-anchors only as far as it can and the row's
        // trailing end stays flush with the viewport.
        var context = makeContext(focused: w5, slot: 400)
        context.scrollRest = ScrollRest(
            offset: -1000,
            focus: w5,
            position: 1600,
            span: 400
        )
        context.scrolling.slotSize = .points(300)
        let frames = layout.calculateGeometry(
            for: windows,
            in: context
        )
        #expect(try lead(of: w5, in: frames, context) == 700)
        let last = try #require(frames[w5])
        #expect(abs(last.maxX - context.usable.maxX) < 0.01)
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
            position: 1200,
            span: 400
        )
        let frames = layout.calculateGeometry(
            for: [w2, w3, w4, w5],
            in: context
        )
        #expect(try lead(of: w4, in: frames, context) == 400)
    }
}
