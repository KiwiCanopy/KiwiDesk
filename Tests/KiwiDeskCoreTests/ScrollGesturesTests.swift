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
/// while the core is started AND a wired consumer has a chord,
/// and a routed event reaches the consumer that owns its gesture.
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

    private func settings(
        pan: ScrollChord? = ScrollGesturesTests.pan,
        step: ScrollChord? = ScrollGesturesTests.step,
        natural: Bool = true
    ) -> ScrollGestureSettings {
        var chords: [ScrollGestures.Consumer: ScrollChord] = [:]
        chords[.pan] = pan
        chords[.step] = step
        return ScrollGestureSettings(
            chords: chords,
            naturalScrolling: natural
        )
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

    @Test("no tap until started, wired and given a chord")
    func tapFollowsSettings() {
        let (gestures, made) = front()
        gestures.configure(settings(step: nil))
        gestures.start()
        #expect(made().isEmpty)
        gestures.setHandler(.pan) { _ in }
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan])
        gestures.setHandler(.step) { _ in }
        gestures.configure(settings())
        #expect(made().count == 1)
        #expect(made().first?.chords == [Self.pan, Self.step])
        gestures.configure(settings(pan: nil, step: nil))
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
    }

    @Test("stop tears the tap down and drops what was still queued")
    func stopTearsDown() {
        let (gestures, made) = front()
        var heard = 0
        gestures.setHandler(.pan) { _ in heard += 1 }
        gestures.configure(settings(step: nil))
        gestures.start()
        gestures.stop()
        #expect(made().first?.stopped == true)
        #expect(!gestures.isTapped)
        gestures.receive([event(Self.pan, .began)])
        #expect(heard == 0)
    }

    @Test("a stop ends a gesture in flight")
    func stopEndsInFlight() {
        let (gestures, _) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.setHandler(.pan) { heard.append($0.kind) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.stop()
        #expect(heard == [.began, .ended])
        gestures.start()
        gestures.receive([event(Self.pan, .changed)])
        #expect(heard == [.began, .ended])
    }

    @Test("a plain scroll can never be configured")
    func emptyChordRefused() {
        let (gestures, made) = front()
        gestures.setHandler(.pan) { _ in }
        gestures.start()
        gestures.configure(settings(pan: [], step: nil))
        #expect(made().isEmpty)
        #expect(gestures.settings.chords.isEmpty)
    }

    @Test("an event reaches its own chord's consumer")
    func routesByChord() {
        let (gestures, _) = front()
        var heard: [ScrollGestures.Consumer] = []
        gestures.setHandler(.pan) { _ in heard.append(.pan) }
        gestures.setHandler(.step) { _ in heard.append(.step) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.receive([event(Self.step, .began)])
        #expect(heard == [.pan, .step])
    }

    @Test("a chord both gestures hold reaches the pan, never a coin flip")
    func sharedChordPrecedence() {
        let (gestures, _) = front()
        var heard: [ScrollGestures.Consumer] = []
        gestures.setHandler(.step) { _ in heard.append(.step) }
        gestures.setHandler(.pan) { _ in heard.append(.pan) }
        gestures.configure(settings(step: Self.pan))
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        #expect(heard == [.pan])
    }

    @Test("two gestures trading chords land in one configure")
    func swapKeepsBoth() {
        let (gestures, made) = front()
        var heard: [ScrollGestures.Consumer] = []
        gestures.setHandler(.pan) { _ in heard.append(.pan) }
        gestures.setHandler(.step) { _ in heard.append(.step) }
        gestures.configure(settings())
        gestures.start()
        gestures.configure(settings(pan: Self.step, step: Self.pan))
        #expect(made().last?.chords == [Self.pan, Self.step])
        gestures.receive([event(Self.step, .began)])
        gestures.receive([event(Self.pan, .began)])
        #expect(heard == [.pan, .step])
    }

    @Test("a changed chord ends the gesture and strands the rest")
    func changeMidGesture() {
        let (gestures, _) = front()
        var panHeard: [ScrollGestureEvent] = []
        var stepHeard: [ScrollGestureEvent.Kind] = []
        gestures.setHandler(.pan) { panHeard.append($0) }
        gestures.setHandler(.step) { stepHeard.append($0.kind) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.configure(settings(pan: Self.step, step: Self.pan))
        gestures.receive([
            event(Self.pan, .changed), event(Self.pan, .ended),
        ])
        #expect(panHeard.map(\.kind) == [.began, .ended])
        #expect(panHeard.last?.location == CGPoint(x: 7, y: 9))
        #expect(stepHeard.isEmpty)
    }

    @Test("re-applying the same settings keeps a live gesture")
    func sameSettingsKeepGesture() {
        let (gestures, _) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.setHandler(.pan) { heard.append($0.kind) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.configure(settings())
        gestures.configure(settings(natural: false))
        gestures.receive([event(Self.pan, .changed)])
        #expect(heard == [.began, .changed])
    }

    @Test("Natural scrolling off flips the delta, once, here")
    func naturalScrollingFlips() {
        let (gestures, _) = front()
        var deltas: [Double] = []
        gestures.setHandler(.pan) { deltas.append($0.delta.dx) }
        gestures.configure(settings())
        gestures.start()
        gestures.receive([event(Self.pan, .began)])
        gestures.receive([event(Self.pan, .changed, dx: 5)])
        gestures.configure(settings(natural: false))
        gestures.receive([event(Self.pan, .changed, dx: 5)])
        #expect(deltas == [0, 5, -5])
    }

    @Test("what the tap routes reaches the consumer on the main queue")
    func tapDeliveryReachesConsumer() async {
        let (gestures, made) = front()
        var heard: [ScrollGestureEvent.Kind] = []
        gestures.setHandler(.pan) { heard.append($0.kind) }
        gestures.configure(settings())
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
        tracker.scroll.setHandler(.pan) { _ in }
        tracker.scroll.configure(settings())
        #expect(made == 0)
        tracker.start()
        #expect(tracker.scroll.isTapped)
        tracker.stop()
        #expect(!tracker.scroll.isTapped)
        #expect(made == 1)
    }

    @Test("a refused tap is retried on the next change")
    func refusalRetries() {
        let gestures = ScrollGestures()
        var attempts = 0
        gestures.makeTap = { _ in
            attempts += 1
            return nil
        }
        gestures.onLog = { _ in }
        gestures.start()
        gestures.setHandler(.pan) { _ in }
        gestures.configure(settings())
        gestures.setHandler(.step) { _ in }
        #expect(attempts == 2)
        #expect(!gestures.isTapped)
    }
}
