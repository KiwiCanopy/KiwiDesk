import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The grab's frame math (#2447 ruling 2026-11-08): a resize
/// takes the nearest corner, and a grab in the middle third of an
/// edge moves that edge alone.
@Suite("ModifierGrabGeometry")
struct ModifierGrabGeometryTests {
    private let frame = CGRect(x: 100, y: 100, width: 300, height: 300)
    private typealias Handle = ModifierGrabGeometry.Handle

    private func handle(_ x: CGFloat, _ y: CGFloat) -> Handle {
        ModifierGrabGeometry.handle(at: CGPoint(x: x, y: y), on: frame)
    }

    @Test("corner cells take their corner")
    func corners() {
        #expect(handle(120, 120) == Handle(x: -1, y: -1))
        #expect(handle(380, 120) == Handle(x: 1, y: -1))
        #expect(handle(120, 380) == Handle(x: -1, y: 1))
        #expect(handle(380, 380) == Handle(x: 1, y: 1))
    }

    @Test("the middle third of an edge moves that edge alone")
    func edges() {
        #expect(handle(250, 120) == Handle(x: 0, y: -1))
        #expect(handle(250, 380) == Handle(x: 0, y: 1))
        #expect(handle(120, 250) == Handle(x: -1, y: 0))
        #expect(handle(380, 250) == Handle(x: 1, y: 0))
    }

    @Test("the thirds fall at a third and two thirds of each side")
    func thirdsBoundaries() {
        // Just inside and just past each boundary, from the frame.
        // Above the middle, so the centre cell reads its top corners.
        let y = frame.midY - 10
        let nudge: CGFloat = 2
        let first = frame.minX + frame.width / 3
        let second = frame.minX + frame.width * 2 / 3
        #expect(handle(first - nudge, y) == Handle(x: -1, y: 0))
        #expect(handle(first + nudge, y) == Handle(x: -1, y: -1))
        #expect(handle(second - nudge, y) == Handle(x: 1, y: -1))
        #expect(handle(second + nudge, y) == Handle(x: 1, y: 0))
    }

    @Test("the centre cell takes the corner of its quadrant")
    func centre() {
        #expect(handle(240, 240) == Handle(x: -1, y: -1))
        #expect(handle(260, 260) == Handle(x: 1, y: 1))
        #expect(handle(260, 240) == Handle(x: 1, y: -1))
    }

    @Test("a move offsets the start frame by the travel")
    func move() {
        let moved = ModifierGrabGeometry.moved(
            frame,
            from: CGPoint(x: 150, y: 150),
            to: CGPoint(x: 170, y: 140)
        )
        #expect(moved == CGRect(x: 120, y: 90, width: 300, height: 300))
    }

    @Test("a corner resize keeps the opposite corner")
    func cornerResize() {
        let resized = ModifierGrabGeometry.resized(
            frame,
            handle: Handle(x: 1, y: 1),
            from: CGPoint(x: 390, y: 390),
            to: CGPoint(x: 420, y: 350)
        )
        #expect(resized == CGRect(x: 100, y: 100, width: 330, height: 260))
        let topLeft = ModifierGrabGeometry.resized(
            frame,
            handle: Handle(x: -1, y: -1),
            from: CGPoint(x: 110, y: 110),
            to: CGPoint(x: 90, y: 130)
        )
        #expect(topLeft == CGRect(x: 80, y: 120, width: 320, height: 280))
    }

    @Test("an edge resize leaves the other axis alone")
    func edgeResize() {
        let resized = ModifierGrabGeometry.resized(
            frame,
            handle: Handle(x: 0, y: 1),
            from: CGPoint(x: 250, y: 390),
            to: CGPoint(x: 300, y: 450)
        )
        #expect(resized == CGRect(x: 100, y: 100, width: 300, height: 360))
    }

    @Test("a resize stops at the minimum side, never inverting")
    func minimum() {
        let side = ModifierGrabGeometry.minimumSide
        let shrunk = ModifierGrabGeometry.resized(
            frame,
            handle: Handle(x: 1, y: -1),
            from: CGPoint(x: 390, y: 110),
            to: CGPoint(x: -1000, y: 2000)
        )
        #expect(shrunk.width == side)
        #expect(shrunk.height == side)
        #expect(shrunk.minX == frame.minX)
        #expect(shrunk.maxY == frame.maxY)
    }
}
