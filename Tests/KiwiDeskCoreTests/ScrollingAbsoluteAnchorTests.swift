import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// `center`, `start` and `end` are absolute (#1388): the focused
/// window rests where the anchor says even with no neighbour on
/// one side, so a short row on a wide screen leaves the rest
/// empty rather than being pulled flush to the leading edge.
/// `follow` keeps the row-extent clamp — it is the anchor that
/// promises a filled screen.
@Suite("Scrolling absolute anchors (#1388)")
struct ScrollingAbsoluteAnchorTests {
    /// 1920 pt across, two 400 pt slots: the row is 810 pt, far
    /// shorter than the axis, so the old clamp would have pinned
    /// it at the leading edge under every anchor.
    private func context(
        anchor: ScrollingParams.Anchor,
        focused: WindowID
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10),
            focused: focused
        )
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .points(400)
        context.scrolling.anchor = anchor
        return context
    }

    private func frame(
        _ anchor: ScrollingParams.Anchor,
        focused: WindowID = w1
    ) throws -> (focused: CGRect, usable: CGRect) {
        let context = context(anchor: anchor, focused: focused)
        let frames = ScrollingLayout().calculateGeometry(
            for: [w1, w2],
            in: context
        )
        return (try #require(frames[focused]), context.usable)
    }

    @Test("center centres a short row's focus on the screen")
    func centerIsAbsolute() throws {
        let (f, usable) = try frame(.center)
        #expect(abs(f.midX - usable.midX) < 0.01)
    }

    @Test("start rests the focus at the leading edge")
    func startIsAbsolute() throws {
        // The second window focused: under the clamp the row's
        // start would have stayed at the edge with w2 beside it;
        // absolute, w2 itself takes the edge and w1 hangs off it.
        let (f, usable) = try frame(.start, focused: w2)
        #expect(abs(f.minX - usable.minX) < 0.01)
    }

    @Test("end rests the focus at the trailing edge")
    func endIsAbsolute() throws {
        let (f, usable) = try frame(.end)
        #expect(abs(f.maxX - usable.maxX) < 0.01)
    }

    @Test("follow keeps a short row at the leading edge")
    func followKeepsTheClamp() throws {
        let (f, usable) = try frame(.follow, focused: w2)
        // w2 sits after w1, which is flush at the edge.
        #expect(abs(f.minX - (usable.minX + 410)) < 0.01)
    }

    private func held(
        _ anchor: ScrollingParams.Anchor,
        _ offset: CGFloat,
        rowLength: CGFloat
    ) -> CGFloat {
        ScrollingLayout.offset(
            anchor: anchor,
            previous: ScrollRest(offset: offset),
            focus: nil,
            along: 1900,
            size: 400,
            rowLength: rowLength,
            focusedPos: nil
        )
    }

    @Test("a floating focus holds the absolute rest on screen")
    func floatingFocusHolds() {
        // No slot to place: a fixed anchor keeps the previous
        // rest, not clamped back to the leading edge...
        #expect(held(.center, 555, rowLength: 810) == 555)
        // ...but a rest measured against a row that has since
        // shrunk is bounded so the row stays on screen (#966):
        // a short row anywhere inside the axis, a long one with
        // no margin past either end.
        #expect(held(.center, 1700, rowLength: 810) == 1090)
        #expect(held(.end, -300, rowLength: 810) == 0)
        #expect(held(.start, 100, rowLength: 3000) == 0)
        #expect(held(.center, -2000, rowLength: 3000) == -1100)
        // `follow` keeps its own clamp: a short row leads.
        #expect(held(.follow, 555, rowLength: 810) == 0)
    }

    /// A fixed anchor keeps anchoring the last tiled focus while
    /// a float holds focus: the rest remembers it (#966) and its
    /// place is re-derived from the live row, so a neighbour
    /// closing meanwhile moves nothing stale. Only once that
    /// window has left the row does the hold arm bound the number.
    @Test("a float focus keeps the remembered window anchored")
    func floatFocusAnchorsTheRememberedWindow() throws {
        let float = WindowID(9)
        let w3 = WindowID(3)
        var context = context(anchor: .start, focused: w2)
        let rest = ScrollingLayout.viewportRest(
            for: [w1, w2, w3],
            in: context
        )
        #expect(rest.offset == -410)
        #expect(rest.slot?.window == w2)
        // The float takes focus: w2 stays at the edge.
        context.focused = float
        context.scrollRest = rest
        let held = ScrollingLayout.viewportRest(
            for: [w1, w2, w3],
            in: context
        )
        #expect(held.offset == -410)
        #expect(held.slot?.window == w2)
        let frame = try #require(
            ScrollingLayout().calculateGeometry(
                for: [w1, w2, w3],
                in: context
            )[w2]
        )
        #expect(abs(frame.minX - context.usable.minX) < 0.01)
        // w2 closes while the float is focused: the row that is
        // left is bounded onto the screen, not pushed off it.
        context.scrollRest = held
        let gone = ScrollingLayout.viewportRest(
            for: [w1, w3],
            in: context
        )
        #expect(gone.offset == 0)
    }

    /// The rest is recorded for a lone window kept at its slot
    /// (#1389) exactly as for a row — a fill records nothing.
    @Test("a lone kept window records its rest")
    func loneKeptWindowRecordsRest() {
        var context = context(anchor: .center, focused: w1)
        context.scrolling.fillWhenAlone = false
        let rest = ScrollingLayout.viewportRest(
            for: [w1],
            in: context
        )
        #expect(abs(rest.offset - (context.usable.width - 400) / 2) < 0.01)
        #expect(rest.slot?.window == w1)
        context.scrolling.fillWhenAlone = true
        context.scrollRest = ScrollRest(offset: 123)
        #expect(
            ScrollingLayout.viewportRest(for: [w1], in: context).offset
                == 123
        )
    }

    /// The pile gate (#150/#674) asks the DRAWN offset: a short
    /// row under a fixed anchor can still hang off an edge.
    @Test("the overflow verdict follows the drawn offset")
    func overflowFollowsTheOffset() {
        let windows = [w1, w2, WindowID(3)]
        // `start` focusing the last: the two before it hang off
        // the leading edge, though the row is shorter than the axis.
        #expect(
            ScrollingLayout.rowOverflows(
                for: windows,
                in: context(anchor: .start, focused: WindowID(3))
            )
        )
        // `end` focusing the first mirrors it.
        #expect(
            ScrollingLayout.rowOverflows(
                for: windows,
                in: context(anchor: .end, focused: w1)
            )
        )
        // Centred, the short row fits.
        #expect(
            !ScrollingLayout.rowOverflows(
                for: windows,
                in: context(anchor: .center, focused: w2)
            )
        )
        // `follow` reads as it always did: a short row never piles.
        #expect(
            !ScrollingLayout.rowOverflows(
                for: windows,
                in: context(anchor: .follow, focused: WindowID(3))
            )
        )
    }

    @Test("the class has one home")
    func classHasOneHome() {
        for anchor in ScrollingParams.Anchor.allCases {
            #expect(anchor.keepsRowOnScreen == (anchor == .follow))
        }
    }
}
