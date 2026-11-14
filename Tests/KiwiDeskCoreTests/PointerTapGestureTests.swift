import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pointer tap's gesture decision (#1873): a magnification or
/// rotation begun with a bound chord is swallowed to its end with
/// the touch frames carrying that chord, fires one step once its
/// sum crosses the threshold, and every other gesture passes.
@Suite("Pointer tap gestures")
struct PointerTapGestureTests {
    private static let keys: ScrollChord = [.control, .option]
    private static let zoom = GestureEventSample.magnify
    private static let turn = GestureEventSample.rotation

    private func router(
        _ chords: [GestureInput: Set<ScrollChord>]
    ) -> PointerTapRouter {
        var router = PointerTapRouter()
        router.snapshot = PointerTapSnapshot(
            grab: nil,
            gestures: GestureEventSettings(chords)
        )
        return router
    }

    private func g(
        _ subtype: Int,
        _ phase: Int,
        _ value: Double = 0,
        _ chord: ScrollChord = keys
    ) -> PointerSample {
        PointerSample(
            kind: .gesture(
                GestureEventSample(
                    subtype: subtype,
                    phase: phase,
                    value: value
                )
            ),
            location: .zero,
            chord: chord
        )
    }

    @Test("a bound spread is swallowed to its end and fires once")
    func spreadFiresOnce() {
        var r = router([.spread: [Self.keys]])
        #expect(r.route(g(Self.zoom, 1, 0.01), now: 1).swallow)
        let mid = r.route(g(Self.zoom, 2, 0.2), now: 1.01)
        #expect(mid.swallow)
        #expect(mid.gestures.isEmpty, "under the threshold")
        let fired = r.route(g(Self.zoom, 2, 0.2), now: 1.02)
        #expect(fired.gestures.map(\.kind) == [.gesture(.spread)])
        #expect(fired.gestures.first?.modifiers == Self.keys)
        let more = r.route(g(Self.zoom, 2, 0.5), now: 1.03)
        #expect(more.swallow)
        #expect(more.gestures.isEmpty, "one step per stream")
        // A touch frame inside the stream is the stream's too.
        #expect(r.route(g(0, 0), now: 1.04).swallow)
        #expect(r.route(g(Self.zoom, 4), now: 1.05).swallow)
        // Over: the next frame is the app's.
        #expect(r.route(g(0, 0), now: 1.06) == .pass)
    }

    @Test("pinch together fires on a closing magnification")
    func pinchTogether() {
        var r = router([.pinchTogether: [Self.keys]])
        _ = r.route(g(Self.zoom, 1), now: 1)
        let fired = r.route(g(Self.zoom, 2, -0.35), now: 1.01)
        #expect(fired.gestures.map(\.kind) == [.gesture(.pinchTogether)])
    }

    @Test("the unbound direction is swallowed but fires nothing")
    func unboundDirectionFiresNothing() {
        var r = router([.spread: [Self.keys]])
        _ = r.route(g(Self.zoom, 1), now: 1)
        let closing = r.route(g(Self.zoom, 2, -0.5), now: 1.01)
        #expect(closing.swallow)
        #expect(closing.gestures.isEmpty)
    }

    @Test("a bound rotation fires past its degrees")
    func rotationFires() {
        var r = router([.rotate: [Self.keys]])
        #expect(r.route(g(Self.turn, 1, 1), now: 1).swallow)
        #expect(r.route(g(Self.turn, 2, 3), now: 1.01).gestures.isEmpty)
        let fired = r.route(g(Self.turn, 2, 2), now: 1.02)
        #expect(fired.gestures.map(\.kind) == [.gesture(.rotate)])
    }

    @Test("other keys, no keys, or no binding: every gesture passes")
    func unboundPasses() {
        var r = router([.spread: [Self.keys]])
        #expect(r.route(g(Self.zoom, 1, 0, []), now: 1) == .pass)
        #expect(r.route(g(Self.zoom, 2, 0.9, []), now: 1.01) == .pass)
        #expect(r.route(g(Self.zoom, 1, 0, [.control]), now: 2) == .pass)
        // A rotation is no spread's.
        #expect(r.route(g(Self.turn, 1), now: 3) == .pass)
        // Only a begin opens a stream.
        #expect(r.route(g(Self.zoom, 2, 0.9), now: 4) == .pass)
        var off = PointerTapRouter()
        #expect(off.route(g(Self.zoom, 1), now: 5) == .pass)
    }

    @Test("a touch frame with other keys inside the stream passes")
    func companionNeedsTheKeys() {
        var r = router([.spread: [Self.keys]])
        _ = r.route(g(Self.zoom, 1), now: 1)
        #expect(r.route(g(0, 0, 0, []), now: 1.01) == .pass)
        // The stream's own events stay its, whatever the keys do.
        #expect(r.route(g(Self.zoom, 2, 0.1, []), now: 1.02).swallow)
    }

    @Test("a stream whose end was lost lapses")
    func lostEndLapses() {
        var r = router([.spread: [Self.keys]])
        _ = r.route(g(Self.zoom, 1), now: 1)
        let later = 1 + PointerTapRouter.streamLapse + 0.1
        #expect(r.route(g(0, 0, 0, Self.keys), now: later) == .pass)
    }

    @Test("a re-enable drops the stream")
    func reseedDropsTheStream() {
        var r = router([.spread: [Self.keys]])
        _ = r.route(g(Self.zoom, 1), now: 1)
        _ = r.reseed(now: 1.01)
        #expect(r.route(g(0, 0), now: 1.02) == .pass)
    }

    @Test("Force Click and an empty chord set never reach the settings")
    func forceClickIsLeftOut() {
        let settings = GestureEventSettings([
            .forceClick: [Self.keys], .rotate: [], .spread: [Self.keys],
        ])
        #expect(settings.chords == [.spread: [Self.keys]])
        #expect(!GestureEventSettings().isOn)
        for input: GestureInput in [
            .spread, .pinchTogether, .rotate, .spread4, .pinchTogether4,
        ] {
            #expect(input.isFired, "\(input)")
        }
        #expect(!GestureInput.forceClick.isFired)
    }

    @Test("the gesture mask is types 29 and 30 alone")
    func maskIsGestureOnly() {
        #expect(
            PointerConsumers.gestureMask
                == CGEventMask(1) << 29 | CGEventMask(1) << 30
        )
        #expect(
            PointerConsumers.Consumer.gestures.mask
                == PointerConsumers.gestureMask
        )
    }

    private func dock(
        _ phase: Int,
        _ progress: Double = 0,
        axis: Int = GestureEventSample.dockPinch,
        _ chord: ScrollChord = keys
    ) -> PointerSample {
        PointerSample(
            kind: .gesture(
                GestureEventSample(
                    subtype: 23,
                    phase: phase,
                    value: progress,
                    dock: true,
                    axis: axis
                )
            ),
            location: .zero,
            chord: chord
        )
    }

    @Test("a bound four-finger pinch takes the Dock stream whole")
    func dockStreamIsWhole() {
        var r = router([.pinchTogether4: [Self.keys]])
        #expect(r.route(dock(1, -0.02), now: 1).swallow)
        #expect(r.route(dock(2, -0.1), now: 1.01).gestures.isEmpty)
        // Keys let go mid-stream: still the stream's, never a part.
        let fired = r.route(dock(2, -0.4, []), now: 1.02)
        #expect(fired.swallow)
        #expect(fired.gestures.map(\.kind) == [.gesture(.pinchTogether4)])
        #expect(r.route(dock(2, -0.9, []), now: 1.03).gestures.isEmpty)
        // A type-29 frame with the keys is the stream's meanwhile.
        #expect(r.route(g(0, 0), now: 1.04).swallow)
        #expect(r.route(dock(4, -1.0, []), now: 1.05).swallow)
        #expect(r.route(g(0, 0), now: 1.06) == .pass, "the stream ended")
        // One stream serves both ways: a spread with only pinch
        // together bound is taken whole and fires nothing.
        #expect(r.route(dock(1, 0.02), now: 2).swallow)
        #expect(r.route(dock(2, 0.6), now: 2.01).gestures.isEmpty)
    }

    @Test("a gesture begun before the stream stays the app's")
    func earlierBeginPasses() {
        var r = router([.spread: [Self.keys]])
        // The rotation began before any stream: the app has it.
        #expect(r.route(g(Self.turn, 1, 1), now: 1) == .pass)
        #expect(r.route(g(Self.zoom, 1), now: 1.01).swallow)
        #expect(r.route(g(Self.turn, 2, 3), now: 1.02) == .pass)
        #expect(r.route(g(Self.turn, 4), now: 1.03) == .pass)
        #expect(r.route(g(Self.zoom, 2, 0.1), now: 1.04).swallow)
    }

    @Test("a Dock begin ends a stream whose end was lost")
    func dockBeginRestarts() {
        var r = router([.spread4: [Self.keys]])
        _ = r.route(dock(1, 0.02), now: 1)
        // No end arrived; a plain begin is the Dock's.
        #expect(r.route(dock(1, 0.02, []), now: 2) == .pass)
        #expect(r.route(dock(2, 0.5, []), now: 2.01) == .pass)
    }

    @Test("a still Dock stream outlives the gesture lapse")
    func dockOutlivesTheLapse() {
        var r = router([.spread4: [Self.keys]])
        _ = r.route(dock(1, 0.02), now: 1)
        let held = 1 + PointerTapRouter.streamLapse + 1
        #expect(r.route(dock(2, 0.1, []), now: held).swallow)
        let gone = held + PointerTapRouter.dockStreamLapse + 0.1
        #expect(r.route(dock(2, 0.1, []), now: gone) == .pass)
    }

    @Test("a four-finger spread fires on a growing progress")
    func dockSpreadFires() {
        var r = router([.spread4: [Self.keys]])
        _ = r.route(dock(1, 0.03), now: 1)
        let fired = r.route(dock(2, 0.5), now: 1.01)
        #expect(fired.gestures.map(\.kind) == [.gesture(.spread4)])
    }

    @Test("a Dock stream is taken only at its begin, with the keys")
    func dockNeedsTheBegin() {
        var r = router([.spread4: [Self.keys]])
        #expect(r.route(dock(2, 0.5), now: 1) == .pass, "no begin")
        #expect(r.route(dock(4, 0.6), now: 1.01) == .pass)
        #expect(r.route(dock(1, 0, []), now: 2) == .pass, "no keys")
        #expect(r.route(dock(2, 0.7, []), now: 2.01) == .pass)
        // A swipe axis is never claimed.
        #expect(r.route(dock(1, 0, axis: 1), now: 3) == .pass)
        #expect(r.route(dock(1, 0, axis: 2), now: 4) == .pass)
    }

    @Test("a Dock event inside a pinch stream is the Dock's")
    func dockInsidePinchPasses() {
        var r = router([.spread: [Self.keys], .spread4: [Self.keys]])
        _ = r.route(g(Self.zoom, 1), now: 1)
        #expect(r.route(dock(1), now: 1.01) == .pass)
        #expect(r.route(g(Self.zoom, 2, 0.1), now: 1.02).swallow)
    }
}
