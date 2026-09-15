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

    @Test("a floating focus holds the absolute rest")
    func floatingFocusHolds() {
        // No slot to place: the previous rest is kept as it is,
        // not clamped back to the row's extent.
        let held = ScrollingLayout.offset(
            anchor: .center,
            previous: ScrollRest(offset: 555),
            focus: nil,
            along: 1900,
            size: 400,
            rowLength: 810,
            focusedPos: nil
        )
        #expect(held == 555)
        let followed = ScrollingLayout.offset(
            anchor: .follow,
            previous: ScrollRest(offset: 555),
            focus: nil,
            along: 1900,
            size: 400,
            rowLength: 810,
            focusedPos: nil
        )
        #expect(followed == 0)
    }
}
