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
        } + [TouchFrame(time: duration + 0.1, contacts: [])]
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
        #expect(run(swipe(4, dx: 0.2, dy: 0.2)).isEmpty)
    }

    @Test("a quick short flick fires, as macOS takes one")
    func flickFires() {
        let events = run(swipe(3, dx: -0.06, dy: 0, over: 0.08))
        #expect(events.map(\.kind) == [.swipe(.left)])
        #expect(
            run(swipe(4, dx: 0, dy: 0.06, over: 0.08)).map(\.kind)
                == [.swipe(.up)]
        )
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
        let lift = TouchFrame(time: 0.5, contacts: [])
        let events = run(rest + flick + [lift])
        #expect(events.map(\.kind) == [.swipe(.right)])
    }

    @Test("fingers landing one by one are no flick")
    func landingIsNoFlick() {
        // Each landing finger moves the centre 0.025 within a few
        // milliseconds; the count change re-measures every time.
        let frames =
            (1...5).map { n in
                TouchFrame(
                    time: Double(n) * 0.005,
                    contacts: fingers(n, x: 0.3, y: 0.5)
                )
            } + [TouchFrame(time: 0.1, contacts: [])]
        #expect(run(frames).map(\.kind) == [.tap])
    }

    @Test("a quick tap that rolls within its travel still taps")
    func rollingTapTaps() {
        let frames =
            (0...5).map { step in
                TouchFrame(
                    time: Double(step) * 0.02,
                    contacts: fingers(
                        3,
                        x: 0.4 + Float(step) * 0.007,
                        y: 0.5
                    )
                )
            } + [TouchFrame(time: 0.11, contacts: [])]
        #expect(run(frames).map(\.kind) == [.tap])
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

/// The `MTTouch` record read (#1873): the touching states, the
/// buffer's end, and positions off the pad.
@Suite("Touch frame parse")
struct TouchFrameParseTests {
    private func record(
        id: Int32,
        state: Int32,
        x: Float,
        y: Float
    ) -> [UInt8] {
        var bytes = [UInt8](
            repeating: 0,
            count: MultitouchSupport.Layout.stride
        )
        func put<T>(_ value: T, at offset: Int) {
            withUnsafeBytes(of: value) { raw in
                for (index, byte) in raw.enumerated() {
                    bytes[offset + index] = byte
                }
            }
        }
        put(id, at: MultitouchSupport.Layout.identifier)
        put(state, at: MultitouchSupport.Layout.state)
        put(x, at: MultitouchSupport.Layout.x)
        put(y, at: MultitouchSupport.Layout.y)
        return bytes
    }

    @Test("touching records parse; hovering ones and overruns drop")
    func parses() {
        let bytes =
            record(id: 7, state: 4, x: 0.25, y: 0.75)
            + record(id: 8, state: 2, x: 0.5, y: 0.5)
            + record(id: 9, state: 3, x: 0.1, y: 0.2)
        let contacts = bytes.withUnsafeBytes {
            MultitouchSupport.contacts(in: $0, count: 4)
        }
        #expect(
            contacts == [
                TouchContact(id: 7, x: 0.25, y: 0.75),
                TouchContact(id: 9, x: 0.1, y: 0.2),
            ]
        )
    }

    @Test("a position off the pad is garbage and dropped")
    func offPadDrops() {
        let bytes =
            record(id: 1, state: 4, x: .nan, y: 0.5)
            + record(id: 2, state: 4, x: 0.5, y: 7)
            + record(id: 3, state: 4, x: -0.2, y: 0.5)
            + record(id: 4, state: 4, x: 1.05, y: -0.05)
        let contacts = bytes.withUnsafeBytes {
            MultitouchSupport.contacts(in: $0, count: 4)
        }
        #expect(contacts.map(\.id) == [4])
    }
}
