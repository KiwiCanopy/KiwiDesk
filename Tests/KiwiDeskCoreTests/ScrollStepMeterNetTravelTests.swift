import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A long swipe's steps count NET finger travel (#3505): a move back
/// subtracts, so a wobble steps nothing, and a pad move is turned
/// the point deltas' way by the event's own Natural setting, never by
/// a frame's point delta, under either setting and on both axes.
@Suite("Scroll step meter, net finger travel")
struct ScrollStepMeterNetTravelTests {
    private let length = 10.0

    /// One frame of a touch: the pad move in mm (x right, y up) and
    /// the point delta that reaches the meter beside it.
    private struct Frame {
        var pad: CGVector
        var points: CGVector
    }

    /// The deltas the meter hears: Natural scrolling's convention,
    /// fingers right as +x and fingers up as -y, reversed whole and
    /// marked `reversed` where it is off.
    private enum Natural {
        case on, off

        func points(_ pad: CGVector, scale: Double = 6) -> CGVector {
            let way = self == .on ? 1.0 : -1.0
            return CGVector(
                dx: pad.dx * scale * way,
                dy: -pad.dy * scale * way
            )
        }
    }

    /// A touch fed its frames; answers each frame's steps.
    private struct Touch {
        var meter: ScrollStepMeter
        var sum = CGVector.zero
        let reversed: Bool

        init(length: Double, natural: Natural = .on) {
            meter = ScrollStepMeter(longSwipes: true, length: length)
            reversed = natural == .off
            _ = meter.feed(
                event(.began, .zero),
                reading: TouchTravel.Reading(sum: .zero, source: 1)
            )
        }

        func event(
            _ kind: ScrollGestureEvent.Kind,
            _ delta: CGVector
        ) -> ScrollGestureEvent {
            var event = ScrollGestureEvent(
                chord: [.control, .option],
                kind: kind,
                input: .trackpad,
                delta: delta,
                momentum: false,
                location: .zero,
                time: 0
            )
            event.reversed = reversed
            return event
        }

        mutating func feed(_ frame: Frame) -> Int {
            sum.dx += frame.pad.dx
            sum.dy += frame.pad.dy
            return meter.feed(
                event(.changed, frame.points),
                reading: TouchTravel.Reading(sum: sum, source: 1)
            )
        }

        mutating func feed(_ frames: [Frame]) -> [Int] {
            frames.map { feed($0) }
        }
    }

    /// A clean swipe of `mm` along one pad axis, in 1 mm frames.
    private func run(
        _ mm: Int,
        dx: Double = 0,
        dy: Double = 0,
        natural: Natural = .on
    ) -> [Frame] {
        let pad = CGVector(dx: dx, dy: dy)
        return Array(
            repeating: Frame(pad: pad, points: natural.points(pad)),
            count: mm
        )
    }

    /// The fingers rocking on the spot while macOS's smoothed point
    /// deltas still run forward step nothing: each move back cancels
    /// the move before it.
    @Test("a wobble that nets zero steps nothing")
    func wobbleStepsNothing() {
        var touch = Touch(length: length)
        #expect(touch.feed(run(10, dx: 1)).reduce(0, +) == 1)
        let rock = (0..<20).map { index in
            Frame(
                pad: CGVector(dx: index.isMultiple(of: 2) ? 3 : -3, dy: 0),
                points: CGVector(dx: 6, dy: 0)
            )
        }
        #expect(touch.feed(rock).allSatisfy { $0 == 0 })
    }

    /// A vertical swipe with the fingers placed diagonally: each pair
    /// of frames sways sideways and rocks on y, and the steps come one
    /// per `length` of NET travel down, never per path walked —
    /// whichever way the touch starts rocking.
    @Test("a diagonal two-finger vertical swipe steps per length")
    func diagonalVerticalSwipe() {
        for backFirst in [false, true] {
            var touch = Touch(length: length)
            // 2 mm down, 1 mm back up, swaying ±1.5 mm sideways: a
            // net 1 mm down per pair of frames, 3 mm of path.
            let frames = (0..<60).map { index -> Frame in
                let down = index.isMultiple(of: 2) != backFirst
                let pad = CGVector(
                    dx: down ? 1.5 : -1.5,
                    dy: down ? -2 : 1
                )
                // Smoothed points: always down (+y, Natural on).
                return Frame(pad: pad, points: CGVector(dx: 0, dy: 12))
            }
            let steps = touch.feed(frames)
            #expect(steps.reduce(0, +) == 3, "back first: \(backFirst)")
            #expect(steps.allSatisfy { $0 >= 0 })
            #expect(touch.meter.firedHorizontal == false)
        }
    }

    /// A reversal mid-swipe steps back the other way once the net
    /// travel back covers the remainder and one length.
    @Test("a reversal steps back the other way")
    func reversal() {
        for natural in [Natural.on, .off] {
            var touch = Touch(length: length, natural: natural)
            let out = touch.feed(run(24, dx: 1, natural: natural))
            #expect(out.reduce(0, +) == (natural == .on ? 2 : -2))
            // 4 mm left over; 13 mm back is short of a step.
            let back = touch.feed(run(13, dx: -1, natural: natural))
            #expect(back.allSatisfy { $0 == 0 })
            let one = touch.feed(run(1, dx: -1, natural: natural))
            #expect(one == [natural == .on ? -1 : 1])
        }
    }

    /// The step's sign is the point deltas' way under both Natural
    /// settings, on both axes.
    @Test("both Natural settings, both axes")
    func bothNaturalSettings() {
        for natural in [Natural.on, .off] {
            for horizontal in [true, false] {
                var touch = Touch(length: length, natural: natural)
                let pad = CGVector(
                    dx: horizontal ? 1 : 0,
                    dy: horizontal ? 0 : 1
                )
                let frames = run(
                    30,
                    dx: pad.dx,
                    dy: pad.dy,
                    natural: natural
                )
                let way = natural.points(pad)
                let sign = (horizontal ? way.dx : way.dy) > 0 ? 1 : -1
                #expect(touch.feed(frames).reduce(0, +) == 3 * sign)
                #expect(touch.meter.firedHorizontal == horizontal)
            }
        }
    }

    /// A turn onto the other axis steps the way the turn goes, the
    /// fingers having drifted the other way on it meanwhile: right,
    /// right while drifting down, then up, under Natural off.
    @Test("a turn after a drift takes the new axis's way")
    func turnAfterADrift() {
        var touch = Touch(length: length, natural: .off)
        let drift = Frame(
            pad: CGVector(dx: 1, dy: -0.15),
            points: Natural.off.points(CGVector(dx: 1, dy: 0))
        )
        let right = touch.feed(Array(repeating: drift, count: 20))
        #expect(right.reduce(0, +) == -2)
        let up = touch.feed(run(10, dy: 1, natural: .off))
        // Natural off: fingers up report +y.
        #expect(up.reduce(0, +) == 1)
        #expect(touch.meter.firedHorizontal == false)
    }

    /// The meter's way is the hand convention `GestureMotionLatch`
    /// reads directions in: a pad move turned by `pointWay` names the
    /// fingers' own direction there, on both axes.
    @Test("the way is the direction latch's convention")
    func wayMatchesTheLatch() {
        let cases: [(CGVector, GestureDirection)] = [
            (CGVector(dx: 30, dy: 0), .right),
            (CGVector(dx: -30, dy: 0), .left),
            (CGVector(dx: 0, dy: 30), .up),
            (CGVector(dx: 0, dy: -30), .down),
        ]
        for (pad, direction) in cases {
            var latch = GestureMotionLatch()
            let event = ScrollGestureEvent(
                chord: [.control, .option],
                kind: .changed,
                input: .trackpad,
                delta: ScrollStepMeter.pointWay(pad, reversed: false),
                momentum: false,
                location: .zero,
                time: 0
            )
            #expect(latch.feed(event) == direction, "\(pad)")
        }
    }
}
