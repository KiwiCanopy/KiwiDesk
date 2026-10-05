import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// What one page of the plate slide shows (#1956): a plate per
/// window clipped to the screen, back to front, and an icon on
/// each pile's front face only — the focus where it is in the
/// pile, else the WindowServer's front-most member.
@Suite("Plate slide plan (#1956)")
struct SpaceSlidePlanTests {
    private let page = CGRect(x: 0, y: 0, width: 1000, height: 800)

    private func entry(
        _ id: UInt32,
        _ frame: CGRect,
        pid: pid_t = 10,
        floating: Bool = false
    ) -> SpaceSlidePlan.Entry {
        SpaceSlidePlan.Entry(
            id: WindowID(id),
            frame: frame,
            pid: pid,
            floats: floating
        )
    }

    @Test("a plate is the part of its window the page shows")
    func platesClipToThePage() {
        let plates = SpaceSlidePlan.plates(
            [
                entry(1, CGRect(x: -200, y: 0, width: 500, height: 800)),
                // A parked window's sliver draws nothing.
                entry(2, CGRect(x: 990, y: 780, width: 600, height: 400)),
                // Neither does a window off the page.
                entry(3, CGRect(x: 1200, y: 0, width: 400, height: 400)),
            ],
            focus: nil,
            stack: [:],
            in: page
        )
        #expect(plates.map(\.id) == [WindowID(1)])
        #expect(
            plates.first?.frame
                == CGRect(x: 0, y: 0, width: 300, height: 800)
        )
    }

    @Test("side by side windows are piles of one, each with an icon")
    func separateWindowsEachCarryAnIcon() {
        let plates = SpaceSlidePlan.plates(
            [
                entry(1, CGRect(x: 0, y: 0, width: 495, height: 800), pid: 1),
                entry(
                    2,
                    CGRect(x: 505, y: 0, width: 495, height: 800),
                    pid: 2
                ),
            ],
            focus: WindowID(1),
            stack: [:],
            in: page
        )
        #expect(Set(plates.map(\.pile)).count == 2)
        #expect(plates.compactMap(\.iconPid).sorted() == [1, 2])
    }

    @Test("a pile's face is the focus where it is in the pile")
    func focusIsTheFace() {
        let a = CGRect(x: 0, y: 0, width: 600, height: 600)
        let b = CGRect(x: 100, y: 100, width: 600, height: 600)
        let plates = SpaceSlidePlan.plates(
            [entry(1, a, pid: 1), entry(2, b, pid: 2)],
            focus: WindowID(1),
            // Window 2 is front-most on the server.
            stack: [2: 0, 1: 1],
            in: page
        )
        #expect(plates.map(\.pile) == [0, 0])
        // The focus draws last in its tier, and alone carries one.
        #expect(plates.last?.id == WindowID(1))
        #expect(plates.compactMap(\.iconPid) == [1])
    }

    @Test("without the focus, the server's front-most member is the face")
    func frontMostIsTheFace() {
        let a = CGRect(x: 0, y: 0, width: 600, height: 600)
        let b = CGRect(x: 100, y: 100, width: 600, height: 600)
        let plates = SpaceSlidePlan.plates(
            [entry(1, a, pid: 1), entry(2, b, pid: 2)],
            focus: nil,
            stack: [1: 0, 2: 1],
            in: page
        )
        #expect(plates.map(\.id) == [WindowID(2), WindowID(1)])
        #expect(plates.compactMap(\.iconPid) == [1])
    }

    /// A float in front of the tiled focus in one pile: the draw
    /// order puts the float last, yet the face is the focus.
    @Test("the focus is the face even under a float")
    func focusOutranksAFloatInFront() {
        let tiled = CGRect(x: 0, y: 0, width: 600, height: 600)
        let float = CGRect(x: 100, y: 100, width: 300, height: 300)
        let plates = SpaceSlidePlan.plates(
            [
                entry(1, tiled, pid: 1),
                entry(2, float, pid: 2, floating: true),
            ],
            focus: WindowID(1),
            stack: [:],
            in: page
        )
        #expect(plates.last?.id == WindowID(2))
        #expect(plates.compactMap(\.iconPid) == [1])
    }

    @Test("a window thin on one axis draws no plate")
    func oneAxisSliverIsDropped() {
        let plates = SpaceSlidePlan.plates(
            [
                entry(1, CGRect(x: 0, y: 0, width: 600, height: 10)),
                entry(2, CGRect(x: 0, y: 100, width: 10, height: 600)),
            ],
            focus: nil,
            stack: [:],
            in: page
        )
        #expect(plates.isEmpty)
    }

    @Test("floats draw above the tiled plane")
    func floatsDrawAbove() {
        let plates = SpaceSlidePlan.plates(
            [
                entry(
                    1,
                    CGRect(x: 100, y: 100, width: 300, height: 300),
                    floating: true
                ),
                entry(2, page),
            ],
            focus: WindowID(2),
            stack: [:],
            in: page
        )
        #expect(plates.map(\.id) == [WindowID(2), WindowID(1)])
    }

    /// Monocle's stacked members, and any exact repeat: a plate
    /// wholly behind another shows nothing, so one plate draws.
    @Test("a plate wholly behind another is dropped")
    func coveredPlateIsDropped() {
        let plates = SpaceSlidePlan.plates(
            [entry(1, page, pid: 1), entry(2, page, pid: 2)],
            focus: WindowID(2),
            stack: [:],
            in: page
        )
        #expect(plates.map(\.id) == [WindowID(2)])
        #expect(plates.first?.iconPid == 2)
    }

    @Test("an icon smaller than its floor is dropped")
    func iconFloor() {
        // The shortest side whose icon reaches the floor, derived.
        let edge = SpaceSlidePlan.iconMinimum / SpaceSlidePlan.iconShare
        #expect(
            SpaceSlidePlan.iconSide(
                on: CGRect(x: 0, y: 0, width: 4000, height: edge - 1)
            ) == nil
        )
        let side = SpaceSlidePlan.iconSide(
            on: CGRect(x: 0, y: 0, width: 4000, height: edge)
        )
        #expect(abs((side ?? 0) - SpaceSlidePlan.iconMinimum) < 0.001)
        #expect(
            SpaceSlidePlan.iconSide(
                on: CGRect(x: 0, y: 0, width: 4000, height: 4000)
            )
                == SpaceSlidePlan.iconMaximum
        )
    }

    @Test("a later Space enters from the trailing side")
    func direction() {
        let order = [SpaceID("1"), SpaceID("b"), SpaceID("2")]
        #expect(
            SpaceSlidePlan.direction(
                from: SpaceID("1"),
                to: SpaceID("2"),
                order: order
            ) == 1
        )
        #expect(
            SpaceSlidePlan.direction(
                from: SpaceID("2"),
                to: SpaceID("b"),
                order: order
            ) == -1
        )
        // Outside the order, as numbers.
        #expect(
            SpaceSlidePlan.direction(
                from: SpaceID("9"),
                to: SpaceID("4"),
                order: []
            ) == -1
        )
    }

    @Test("a side Space Bar slides the strip vertically")
    func axis() {
        #expect(SpaceSlidePlan.axis(spaceBarEdge: .top) == .horizontal)
        #expect(SpaceSlidePlan.axis(spaceBarEdge: .bottom) == .horizontal)
        #expect(SpaceSlidePlan.axis(spaceBarEdge: .left) == .vertical)
        #expect(SpaceSlidePlan.axis(spaceBarEdge: .right) == .vertical)
    }
}
