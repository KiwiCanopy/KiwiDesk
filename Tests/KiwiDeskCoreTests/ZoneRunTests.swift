import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// `ZoneRun.resolve` (#2235): which windows a zone shows, from its
/// head and its focus, at each window's own floor.
@Suite("Zone run")
struct ZoneRunTests {
    /// Four 300 pt floors in 780 pt with 10 pt gaps: two fit.
    private func run(head: Int? = nil, focus: Int? = nil) -> ZoneRun {
        ZoneRun.resolve(
            floors: [300, 300, 300, 300],
            span: 780,
            gap: 10,
            head: head,
            focus: focus
        )
    }

    @Test("Everything that fits is shown, nothing hidden")
    func fitsShowsAll() {
        let all = ZoneRun.resolve(
            floors: [300, 300],
            span: 780,
            gap: 10,
            head: 1,
            focus: nil
        )
        expectEqual(all.visible, 0..<2)
        #expect(!all.hides)
    }

    @Test("A run takes windows from its head while they fit")
    func headLeads() {
        expectEqual(run().visible, 0..<2)
        expectEqual(run(head: 1).visible, 1..<3)
    }

    @Test("Focus past the run scrolls by the smallest step")
    func focusForward() {
        expectEqual(run(focus: 2).visible, 1..<3)
        expectEqual(run(head: 0, focus: 3).visible, 2..<4)
    }

    @Test("Focus before the run brings it back to the focus")
    func focusBackward() {
        expectEqual(run(head: 2, focus: 0).visible, 0..<2)
    }

    @Test("Focus inside the run moves nothing")
    func focusInside() {
        expectEqual(run(head: 1, focus: 2).visible, 1..<3)
    }

    @Test("A pass at rest adds no window, even with room")
    func restAddsNothing() {
        // A head on the last window shows it alone: pulling the
        // run back would reveal a window no focus asked for.
        expectEqual(run(head: 3).visible, 3..<4)
    }

    /// The device case (owner, 2026-10-22): a big window, then
    /// small ones, in 1000 pt with 10 pt gaps.
    private func mixed(
        head: Int? = nil,
        tail: Int? = nil,
        focus: Int? = nil
    ) -> Range<Int> {
        ZoneRun.resolve(
            floors: [500, 300, 300, 300, 300],
            span: 1000,
            gap: 10,
            head: head,
            tail: tail,
            focus: focus
        ).visible
    }

    @Test("A step reveals the focused window and nothing past it")
    func stepRevealsOne() {
        // Shown 0 and 1; focus 2 drops the big one. Windows 1…3
        // would fit, but 3 waits until a step reaches it.
        expectEqual(mixed(head: 0, tail: 1, focus: 2), 1..<3)
        // The next step adds it while the shown ones still fit.
        expectEqual(mixed(head: 1, tail: 2, focus: 3), 1..<4)
    }

    @Test("A run at rest keeps both its ends")
    func restKeepsBothEnds() {
        expectEqual(mixed(head: 1, tail: 2), 1..<3)
        expectEqual(mixed(head: 1, tail: 2, focus: 1), 1..<3)
    }

    /// The one shown window closed: its head hands on, its tail
    /// back, so the tail sits before the head.
    @Test("A tail before the head shows the head alone")
    func staleTailRevealsNothing() {
        expectEqual(mixed(head: 2, tail: 1), 2..<3)
    }

    @Test("Focus before the run becomes its first window")
    func stepBackRevealsOne() {
        expectEqual(mixed(head: 2, tail: 3, focus: 1), 1..<4)
        // The big one joins only by dropping from the far end.
        expectEqual(mixed(head: 1, tail: 3, focus: 0), 0..<2)
    }

    @Test("A run that stops fitting gives up the end away from focus")
    func shrinkAwayFromFocus() {
        expectEqual(mixed(head: 0, tail: 2, focus: 2), 1..<3)
        expectEqual(mixed(head: 0, tail: 2, focus: 0), 0..<2)
    }

    @Test("A floor bigger than the zone is shown alone")
    func oversizedAlone() {
        let alone = ZoneRun.resolve(
            floors: [300, 900, 300],
            span: 780,
            gap: 10,
            head: nil,
            focus: 1
        )
        expectEqual(alone.visible, 1..<2)
    }

    @Test("A larger floor means fewer windows shown")
    func floorsDecide() {
        let fewer = ZoneRun.resolve(
            floors: [500, 300, 300],
            span: 780,
            gap: 10,
            head: nil,
            focus: nil
        )
        expectEqual(fewer.visible, 0..<1)
    }

    @Test("Hidden windows are handed the edge slot RunZone parks")
    func hiddenFrames() {
        let region = CGRect(x: 0, y: 0, width: 100, height: 780)
        let rects = run(head: 1).frames(
            floors: [300, 300, 300, 300],
            weights: [1, 1, 1, 1],
            in: region,
            vertical: true,
            gap: 10
        )
        expectEqual(rects[0], rects[1])
        expectEqual(rects[3], rects[2])
        expectEqual(rects[1].maxY + 10, rects[2].minY)
        expectEqual(rects[2].maxY, 780)
    }

    @Test("The last member a head set names is the zone's head")
    func headReading() {
        let members = [WindowID(1), WindowID(2), WindowID(3)]
        #expect(ZoneRun.head(of: members, in: []) == nil)
        #expect(
            ZoneRun.head(
                of: members,
                in: [WindowID(1), WindowID(3)]
            ) == 2
        )
    }
}
