import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure tap and swipe decision over touch frames (#1873): a
/// gesture is one discrete step per touch, never a pan.
@Suite("Trackpad gesture router")
struct TrackpadGestureRouterTests {
    private static let hyper: ScrollChord = [.control, .option]

    /// `n` fingers side by side, their centre at (x, y).
    private func fingers(
        _ n: Int,
        x: Float,
        y: Float
    ) -> [TouchContact] {
        (0..<n).map {
            TouchContact(id: Int32($0), x: x + Float($0) * 0.05, y: y)
        }
    }

    /// Feeds `frames` in order and collects every event.
    private func run(_ frames: [TouchFrame]) -> [TrackpadGestureEvent] {
        var router = TrackpadGestureRouter()
        return frames.flatMap { router.route($0) }
    }

    private func tap(
        _ n: Int,
        lasting duration: Double = 0.1,
        modifiers: ScrollChord = []
    ) -> [TouchFrame] {
        [
            TouchFrame(time: 0, contacts: fingers(n, x: 0.4, y: 0.5)),
            TouchFrame(
                time: duration / 2,
                contacts: fingers(n, x: 0.4, y: 0.5)
            ),
            TouchFrame(time: duration, contacts: [], modifiers: modifiers),
        ]
    }

    @Test("three, four and five fingers tap; two do not")
    func tapsByCount() {
        for n in 3...5 {
            let events = run(tap(n))
            #expect(events.map(\.kind) == [.tap], "\(n) fingers")
            #expect(events.first?.fingers == n)
        }
        #expect(run(tap(2)).isEmpty)
    }

    @Test("a held touch is no tap")
    func longTouchIsNoTap() {
        #expect(run(tap(3, lasting: 0.6)).isEmpty)
    }

    @Test("a tap carries the modifiers held at the lift")
    func tapCarriesModifiers() {
        let events = run(tap(4, modifiers: Self.hyper))
        #expect(events.first?.modifiers == Self.hyper)
    }

    private func swipe(
        _ n: Int,
        dx: Float,
        dy: Float,
        over duration: Double = 0.1,
        modifiers: ScrollChord = hyper
    ) -> [TouchFrame] {
        (0...10).map { step in
            let t = Float(step) / 10
            return TouchFrame(
                time: Double(step) * duration / 10,
                contacts: fingers(n, x: 0.3 + dx * t, y: 0.5 + dy * t),
                modifiers: modifiers
            )
        } + [
            TouchFrame(
                time: duration + 0.01,
                contacts: [],
                modifiers: modifiers
            )
        ]
    }

    @Test("a swipe fires once, in its direction, and is no tap")
    func swipeFiresOnce() {
        let cases: [(Float, Float, Direction)] = [
            (-0.3, 0, .left), (0.3, 0, .right),
            (0, 0.3, .up), (0, -0.3, .down),
        ]
        for (dx, dy, direction) in cases {
            let events = run(swipe(3, dx: dx, dy: dy))
            #expect(events.map(\.kind) == [.swipe(direction)])
            #expect(events.first?.modifiers == Self.hyper)
            #expect(events.first?.fingers == 3)
        }
    }

    @Test("a short slow or diagonal slide decides nothing")
    func shortOrDiagonalSlide() {
        #expect(run(swipe(4, dx: 0.09, dy: 0, over: 1)).isEmpty)
        // Far enough for a flick at 0.2 pad/s, too slow for one.
        #expect(run(swipe(4, dx: 0.06, dy: 0, over: 0.3)).isEmpty)
        #expect(run(swipe(4, dx: 0.2, dy: 0.2)).isEmpty)
    }

    @Test("a quick short flick fires, as macOS takes one")
    func flickFires() {
        let events = run(swipe(3, dx: -0.06, dy: 0, over: 0.08))
        #expect(events.map(\.kind) == [.swipe(.left)])
        #expect(events.first?.modifiers == Self.hyper)
        #expect(
            run(swipe(4, dx: 0, dy: 0.06, over: 0.08)).map(\.kind)
                == [.swipe(.up)]
        )
        #expect(
            run(swipe(3, dx: 0, dy: -0.06, over: 0.08)).map(\.kind)
                == [.swipe(.down)]
        )
    }

    @Test("a slow swipe waits for its distance, never flicking early")
    func slowSwipeWaits() {
        // 0.5 pad/s, past flick speed: 5% at 0.1 s, 12% at 0.24 s.
        let events = run(swipe(3, dx: 0.2, dy: 0, over: 0.4))
        #expect(events.map(\.kind) == [.swipe(.right)])
        #expect((events.first?.time ?? 0) >= 0.23, "fired at 12%")
    }

    @Test("a flick that stops before the lift is no flick")
    func heldFlickIsNoFlick() {
        var frames = swipe(3, dx: 0.06, dy: 0, over: 0.08)
        frames.removeLast()
        let still = fingers(3, x: 0.36, y: 0.5)
        frames += (1...20).map {
            TouchFrame(time: 0.08 + Double($0) * 0.01, contacts: still)
        }
        frames.append(TouchFrame(time: 0.29, contacts: []))
        #expect(run(frames).isEmpty)
    }

    @Test("a release long after the last frame is no flick")
    func staleReleaseIsNoFlick() {
        // The frames stop after the flick; the lift, or a finger's,
        // reaches the router 0.2 s later.
        var frames = swipe(3, dx: -0.06, dy: 0, over: 0.08)
        frames.removeLast()
        let late = TouchFrame(
            time: 0.3,
            contacts: [],
            modifiers: Self.hyper
        )
        #expect(run(frames + [late]).isEmpty)
        let drop = TouchFrame(
            time: 0.3,
            contacts: Array(fingers(3, x: 0.24, y: 0.5).prefix(2)),
            modifiers: Self.hyper
        )
        #expect(run(frames + [drop]).isEmpty)
    }

    @Test("the first finger to lift releases the flick")
    func firstLiftReleases() {
        var frames = swipe(4, dx: -0.07, dy: 0, over: 0.1)
        frames.removeLast()
        frames.append(
            TouchFrame(
                time: 0.11,
                contacts: Array(fingers(4, x: 0.23, y: 0.5).prefix(3)),
                modifiers: Self.hyper
            )
        )
        let events = run(frames)
        #expect(events.map(\.kind) == [.swipe(.left)])
        #expect(events.first?.fingers == 4)
        #expect(events.first?.time == 0.11)
        #expect(events.first?.modifiers == Self.hyper)
    }

    @Test("a flick after a rest still fires")
    func pauseThenFlick() {
        let rest = (0...30).map { step in
            TouchFrame(
                time: Double(step) * 0.01,
                contacts: fingers(3, x: 0.3, y: 0.5),
                modifiers: Self.hyper
            )
        }
        let flick = (1...8).map { step in
            TouchFrame(
                time: 0.3 + Double(step) * 0.01,
                contacts: fingers(
                    3,
                    x: 0.3 + Float(step) * 0.008,
                    y: 0.5
                ),
                modifiers: Self.hyper
            )
        }
        let lift = TouchFrame(
            time: 0.39,
            contacts: [],
            modifiers: Self.hyper
        )
        let events = run(rest + flick + [lift])
        #expect(events.map(\.kind) == [.swipe(.right)])
    }

    @Test("a landing finger's jump is no part of the flick")
    func landingJumpIsNoFlick() {
        // Three fingers rest; a fourth lands far right, jumping the
        // centre 0.06; the four then flick left 0.06 and lift. Read
        // across the landing, the flick would net almost nothing.
        let rest = (0...4).map {
            TouchFrame(
                time: Double($0) * 0.005,
                contacts: fingers(3, x: 0.3, y: 0.5),
                modifiers: Self.hyper
            )
        }
        let lone = TouchContact(id: 9, x: 0.6, y: 0.5)
        let flick = (0...8).map { step in
            let dx = -Float(step) * 0.0075
            return TouchFrame(
                time: 0.025 + Double(step) * 0.01,
                contacts: fingers(3, x: 0.3 + dx, y: 0.5)
                    + [TouchContact(id: 9, x: lone.x + dx, y: 0.5)],
                modifiers: Self.hyper
            )
        }
        let lift = TouchFrame(
            time: 0.11,
            contacts: [],
            modifiers: Self.hyper
        )
        let events = run(rest + flick + [lift])
        #expect(events.map(\.kind) == [.swipe(.left)])
        #expect(events.first?.fingers == 4)
    }

    @Test("a quick tap that rolls within its travel still taps")
    func rollingTapTaps() {
        let frames =
            (0...5).map { step in
                TouchFrame(
                    time: Double(step) * 0.01,
                    contacts: fingers(
                        3,
                        x: 0.4 + Float(step) * 0.007,
                        y: 0.5
                    )
                )
            } + [TouchFrame(time: 0.06, contacts: [])]
        #expect(run(frames).map(\.kind) == [.tap])
        // The roll the tap allows never reaches a flick.
        #expect(
            TrackpadGestureRouter.flickDistance
                > TrackpadGestureRouter.tapTravel
        )
    }

    @Test("a two-finger slide is the scroll gestures', never a swipe")
    func twoFingersNeverSwipe() {
        #expect(run(swipe(2, dx: 0.4, dy: 0)).isEmpty)
    }

    @Test("a finger landing late re-measures from its arrival")
    func countChangeRebaselines() {
        var frames = (0...5).map { step in
            TouchFrame(
                time: Double(step) * 0.01,
                contacts: fingers(2, x: 0.3 + Float(step) * 0.04, y: 0.5)
            )
        }
        // The third finger lands after the two moved 0.2: the
        // travel before it counts for nothing.
        frames.append(
            TouchFrame(time: 0.06, contacts: fingers(3, x: 0.5, y: 0.5))
        )
        frames.append(
            TouchFrame(time: 0.07, contacts: fingers(3, x: 0.53, y: 0.5))
        )
        frames.append(TouchFrame(time: 0.08, contacts: []))
        #expect(run(frames).isEmpty)
    }
}
