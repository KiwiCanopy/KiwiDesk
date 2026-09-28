import CoreGraphics
import Testing

@testable import KiwiDeskCore

private final class FakeTap: ScrollTapHandle {
    var chords: Set<ScrollChord> = []
    var deliver: ScrollGestureTap.Deliver?
    var stopped = false
    func setChords(_ chords: Set<ScrollChord>) { self.chords = chords }
    func stop() { stopped = true }
}

/// The tap's front (#1656, #1519): the machine tap exists only
/// while the core is started AND a gesture is bound, and a routed
/// event reaches the consumer that owns its gesture.
@MainActor
@Suite("Scroll gestures front")
struct ScrollGesturesTests {
    private static let pan: ScrollChord = [.control, .option]
    private static let step: ScrollChord = [.control, .option, .command]

    private func front() -> (ScrollGestures, () -> [FakeTap]) {
        let gestures = ScrollGestures()
        var made: [FakeTap] = []
        gestures.makeTap = { deliver in
            let tap = FakeTap()
            tap.deliver = deliver
            made.append(tap)
            return tap
        }
        gestures.onLog = { _ in }
        return (gestures, { made })
    }

    private func event(
        _ chord: ScrollChord,
        _ kind: ScrollGestureEvent.Kind,
        dx: Double = 0
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: chord,
            kind: kind,
            input: .trackpad,
            delta: CGVector(dx: dx, dy: 0),
            momentum: false,
            location: CGPoint(x: 7, y: 9)
        )
    }

    @Test("no tap until started and bound; none after the last unbind")
    func tapFollowsBindings() {
        let (gestures, made) = front()
        gestures.bind(.pan, to: Self.pan) { _ in }
        #expect(made().isEmpty)
        gestures.start()
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan])
        gestures.bind(.step, to: Self.step) { _ in }
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan, Self.step])
        gestures.bind(.pan, to: nil) { _ in }
        gestures.bind(.step, to: nil) { _ in }
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
    }

    @Test("stop tears the tap down and drops what was still queued")
    func stopTearsDown() {
        let (gestures, made) = front()
        var heard = 0
        gestures.start()
        #expect(made().isEmpty)
        gestures.bind(.pan, to: Self.pan) { _ in heard += 1 }
        gestures.stop()
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
        gestures.receive([event(Self.pan, .began)])
        #expect(heard == 0)
    }

    @Test("a plain scroll can never be bound")
    func emptyChordRefused() {
        let (gestures, made) = front()
        gestures.start()
        gestures.bind(.pan, to: []) { _ in }
        #expect(made().isEmpty)
    }

    @Test("an event reaches its own chord's consumer")
    func routesByChord() {
        let (gestures, _) = front()
        var heard: [ScrollGestures.Consumer] = []
        gestures.start()
        gestures.bind(.pan, to: Self.pan) { _ in heard.append(.pan) }
        gestures.bind(.step, to: Self.step) { _ in heard.append(.step) }
        gestures.receive([event(Self.pan, .began)])
        gestures.receive([event(Self.step, .began)])
        #expect(heard == [.pan, .step])
    }

    @Test("two gestures trading chords both stay bound, either order")
    func swapKeepsBoth() {
        for panFirst in [true, false] {
            let (gestures, made) = front()
            var heard: [ScrollGestures.Consumer] = []
            gestures.start()
            gestures.bind(.pan, to: Self.pan) { _ in heard.append(.pan) }
            gestures.bind(.step, to: Self.step) { _ in
                heard.append(.step)
            }
            let panToStep = {
                gestures.bind(.pan, to: Self.step) { _ in
                    heard.append(.pan)
                }
            }
            let stepToPan = {
                gestures.bind(.step, to: Self.pan) { _ in
                    heard.append(.step)
                }
            }
            if panFirst {
                panToStep()
                stepToPan()
            } else {
                stepToPan()
                panToStep()
            }
            #expect(made().last?.chords == [Self.pan, Self.step])
            gestures.receive([event(Self.step, .began)])
            gestures.receive([event(Self.pan, .began)])
            #expect(heard == [.pan, .step])
        }
    }

    @Test("a rebind ends the consumer's gesture and strands the rest")
    func rebindMidGesture() {
        let (gestures, _) = front()
        var panHeard: [ScrollGestureEvent] = []
        var stepHeard: [ScrollGestureEvent.Kind] = []
        gestures.start()
        gestures.bind(.pan, to: Self.pan) { panHeard.append($0) }
        gestures.bind(.step, to: Self.step) { stepHeard.append($0.kind) }
        gestures.receive([event(Self.pan, .began)])
        gestures.bind(.pan, to: Self.step) { panHeard.append($0) }
        gestures.bind(.step, to: Self.pan) { stepHeard.append($0.kind) }
        gestures.receive([
            event(Self.pan, .changed), event(Self.pan, .ended),
        ])
        #expect(panHeard.map(\.kind) == [.began, .ended])
        #expect(panHeard.last?.location == CGPoint(x: 7, y: 9))
        #expect(stepHeard.isEmpty)
    }

    @Test("Natural scrolling off flips the delta, once, here")
    func naturalScrollingFlips() {
        let (gestures, _) = front()
        var deltas: [Double] = []
        gestures.start()
        gestures.bind(.pan, to: Self.pan) { deltas.append($0.delta.dx) }
        gestures.receive([event(Self.pan, .began)])
        gestures.receive([event(Self.pan, .changed, dx: 5)])
        gestures.naturalScrolling = false
        gestures.receive([event(Self.pan, .changed, dx: 5)])
        #expect(deltas == [0, 5, -5])
    }

    @Test("what the tap routes reaches the consumer on the main queue")
    func tapDeliveryReachesConsumer() async {
        let (gestures, made) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.bind(.pan, to: Self.pan) { heard.append($0.kind) }
        gestures.start()
        made().first?.deliver?([event(Self.pan, .began)])
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
        #expect(heard == [.began])
    }

    @Test("the pointer tracker's start and stop carry the tap")
    func trackerCarriesTheTap() {
        let tracker = MouseTracker()
        var made = 0
        tracker.scroll.makeTap = { _ in
            made += 1
            return FakeTap()
        }
        tracker.scroll.onLog = { _ in }
        tracker.scroll.bind(.pan, to: Self.pan) { _ in }
        #expect(made == 0)
        tracker.start()
        #expect(tracker.scroll.isTapped)
        tracker.stop()
        #expect(!tracker.scroll.isTapped)
        #expect(made == 1)
    }

    @Test("a refused tap is retried on the next bind")
    func refusalRetries() {
        let gestures = ScrollGestures()
        var attempts = 0
        gestures.makeTap = { _ in
            attempts += 1
            return nil
        }
        gestures.onLog = { _ in }
        gestures.start()
        gestures.bind(.pan, to: Self.pan) { _ in }
        gestures.bind(.step, to: Self.step) { _ in }
        #expect(attempts == 2)
        #expect(!gestures.isTapped)
    }
}
