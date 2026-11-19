import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A long swipe's steps count NET finger travel (#3505): a move back
/// subtracts, so a wobble steps nothing, and each pad axis takes the
/// point deltas' way once per touch, under either Natural setting.
@Suite("Scroll step meter, net finger travel")
struct ScrollStepMeterNetTravelTests {
    private let length = 10.0

    /// One frame of a touch: the pad move in mm (x right, y up) and
    /// the point delta macOS reports beside it.
    private struct Frame {
        var pad: CGVector
        var points: CGVector
    }

    /// How a touch's point deltas run against the pad: Natural
    /// scrolling on reports fingers right as +x and fingers up as -y;
    /// off reverses both.
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

    private func event(
        _ kind: ScrollGestureEvent.Kind,
        _ delta: CGVector = .zero
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: [.control, .option],
            kind: kind,
            input: .trackpad,
            delta: delta,
            momentum: false,
            location: .zero,
            time: 0
        )
    }

    /// A touch fed its frames; answers each frame's steps.
    private struct Touch {
        var meter: ScrollStepMeter
        var sum = CGVector.zero

        init(length: Double) {
            meter = ScrollStepMeter(longSwipes: true, length: length)
            _ = meter.feed(
                ScrollGestureEvent(
                    chord: [.control, .option],
                    kind: .began,
                    input: .trackpad,
                    delta: .zero,
                    momentum: false,
                    location: .zero,
                    time: 0
                ),
                reading: TouchTravel.Reading(sum: .zero, source: 1)
            )
        }

        mutating func feed(_ frame: Frame) -> Int {
            sum.dx += frame.pad.dx
            sum.dy += frame.pad.dy
            return meter.feed(
                ScrollGestureEvent(
                    chord: [.control, .option],
                    kind: .changed,
                    input: .trackpad,
                    delta: frame.points,
                    momentum: false,
                    location: .zero,
                    time: 0
                ),
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

    /// Fingers rocking back and forth on the spot while macOS's
    /// smoothed point deltas still run forward step nothing: each
    /// move back cancels the move before it.
    @Test("a wobble that nets zero steps nothing")
    func wobbleStepsNothing() {
        var touch = Touch(length: length)
        // Past the first step on a clean 10 mm.
        #expect(touch.feed(run(10, dx: 1)).reduce(0, +) == 1)
        let rock = (0..<20).map { index in
            Frame(
                pad: CGVector(dx: index.isMultiple(of: 2) ? 3 : -3, dy: 0),
                points: CGVector(dx: 6, dy: 0)
            )
        }
        #expect(touch.feed(rock).allSatisfy { $0 == 0 })
    }

    /// A vertical swipe with the fingers placed diagonally: each frame
    /// drifts sideways and rocks on y, and the steps come one per
    /// `length` of NET travel down, never per path walked.
    @Test("a diagonal two-finger vertical swipe steps per length")
    func diagonalVerticalSwipe() {
        var touch = Touch(length: length)
        // 2 mm down, 1 mm back up, swaying ±1.5 mm sideways: a net
        // 1 mm down per pair of frames, 3 mm of path.
        let frames = (0..<60).map { index -> Frame in
            let down = index.isMultiple(of: 2)
            let pad = CGVector(
                dx: down ? 1.5 : -1.5,
                dy: down ? -2 : 1
            )
            // Smoothed points: always down (Natural on: +y).
            return Frame(pad: pad, points: CGVector(dx: 0, dy: 12))
        }
        let steps = touch.feed(frames)
        // 60 frames, 30 mm net down: three steps, all one way.
        #expect(steps.reduce(0, +) == 3)
        #expect(steps.allSatisfy { $0 >= 0 })
        #expect(touch.meter.firedHorizontal == false)
    }

    /// A reversal mid-swipe steps back the other way once the net
    /// travel back covers the remainder and one length.
    @Test("a reversal steps back the other way")
    func reversal() {
        for natural in [Natural.on, .off] {
            var touch = Touch(length: length)
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
    /// settings, on both axes, read once per touch.
    @Test("both Natural settings, both axes")
    func bothNaturalSettings() {
        for natural in [Natural.on, .off] {
            for horizontal in [true, false] {
                var touch = Touch(length: length)
                let frames = run(
                    30,
                    dx: horizontal ? 1 : 0,
                    dy: horizontal ? 0 : 1,
                    natural: natural
                )
                let way = natural.points(
                    CGVector(dx: horizontal ? 1 : 0, dy: horizontal ? 0 : 1)
                )
                let sign = (horizontal ? way.dx : way.dy) > 0 ? 1 : -1
                #expect(touch.feed(frames).reduce(0, +) == 3 * sign)
                #expect(touch.meter.firedHorizontal == horizontal)
            }
        }
    }

    /// A turn onto the other axis steps that axis's own way: right,
    /// right, then fingers up, under Natural off.
    @Test("a turn takes the new axis's way")
    func turnTakesTheNewAxisWay() {
        var touch = Touch(length: length)
        #expect(touch.feed(run(20, dx: 1, natural: .off)).reduce(0, +) == -2)
        let up = touch.feed(run(10, dy: 1, natural: .off))
        // Natural off: fingers up report +y.
        #expect(up.reduce(0, +) == 1)
        #expect(touch.meter.firedHorizontal == false)
    }
}
