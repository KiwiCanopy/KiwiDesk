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
        #expect(all.visible == 0..<2)
        #expect(!all.hides)
    }

    @Test("A run takes windows from its head while they fit")
    func headLeads() {
        #expect(run().visible == 0..<2)
        #expect(run(head: 1).visible == 1..<3)
    }

    @Test("Focus past the run scrolls by the smallest step")
    func focusForward() {
        #expect(run(focus: 2).visible == 1..<3)
        #expect(run(head: 0, focus: 3).visible == 2..<4)
    }

    @Test("Focus before the run brings it back to the focus")
    func focusBackward() {
        #expect(run(head: 2, focus: 0).visible == 0..<2)
    }

    @Test("Focus inside the run moves nothing")
    func focusInside() {
        #expect(run(head: 1, focus: 2).visible == 1..<3)
    }

    @Test("A fully shown tail pulls back to fill the zone")
    func tailPullsBack() {
        // Head on the last window: the run would show it alone
        // with room for one more, so it starts one earlier.
        #expect(run(head: 3).visible == 2..<4)
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
        #expect(alone.visible == 1..<2)
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
        #expect(fewer.visible == 0..<1)
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
        #expect(rects[0] == rects[1])
        #expect(rects[3] == rects[2])
        #expect(rects[1].maxY + 10 == rects[2].minY)
        #expect(rects[2].maxY == 780)
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
