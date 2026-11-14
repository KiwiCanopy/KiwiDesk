import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pointer tap's Dock-swipe decision (#1873, owner ruling
/// 2026-11-14): a swipe stream is claimed at its begin when a swipe
/// slot binds its keys on its axis, for the finger count the touch
/// reader saw, or for any bound count with no reading; and a slot
/// with no keys never reaches the decision.
@Suite("Pointer tap swipes")
struct PointerTapSwipeTests {
    private static let keys: ScrollChord = [.control, .option]
    private static let h = GestureEventSample.horizontal
    private static let v = GestureEventSample.vertical

    private func router(
        _ bindings: [GestureKey: GestureAction]
    ) -> PointerTapRouter {
        var router = PointerTapRouter()
        router.snapshot = PointerTapSnapshot(
            grab: nil,
            gestures: GestureEventSettings(bindings: bindings)
        )
        return router
    }

    private func swipe(
        _ phase: Int,
        axis: Int,
        fingers: Int,
        _ chord: ScrollChord = keys
    ) -> PointerSample {
        PointerSample(
            kind: .gesture(
                GestureEventSample(
                    subtype: 23,
                    phase: phase,
                    value: 0,
                    dock: true,
                    axis: axis,
                    fingers: fingers
                )
            ),
            location: .zero,
            chord: chord
        )
    }

    @Test("a bound swipe takes its Dock stream whole, by finger count")
    func boundSwipeIsTaken() {
        var r = router([GestureKey(.swipe3, Self.keys): .family(.space)])
        #expect(r.route(swipe(1, axis: Self.h, fingers: 3), now: 1).swallow)
        #expect(
            r.route(swipe(2, axis: Self.h, fingers: 3, []), now: 1.01)
                .swallow,
            "whole, whatever the keys"
        )
        #expect(
            r.route(swipe(4, axis: Self.h, fingers: 3), now: 1.02)
                .swallow
        )
        // Four fingers read: no four-finger slot, so the Dock's.
        #expect(r.route(swipe(1, axis: Self.h, fingers: 4), now: 2) == .pass)
        // The tap never fires a swipe: the touch reader does.
        #expect(
            r.route(swipe(1, axis: Self.v, fingers: 3), now: 3)
                .gestures.isEmpty
        )
    }

    @Test("with no finger reading, any bound count claims the axis")
    func noReadingFallsBack() {
        var r = router([
            GestureKey(.swipe4, Self.keys): .split([
                .left: LuaAction(lua: "a()")
            ])
        ])
        // A four-finger slot claims a stream of unread fingers.
        #expect(r.route(swipe(1, axis: Self.h, fingers: 0), now: 1).swallow)
        #expect(r.route(swipe(4, axis: Self.h, fingers: 0), now: 1.01).swallow)
        // An axis no slot binds stays the Dock's, read or not.
        #expect(r.route(swipe(1, axis: Self.v, fingers: 0), now: 2) == .pass)
        // A reading of a count no slot binds stays the Dock's.
        #expect(r.route(swipe(1, axis: Self.h, fingers: 3), now: 3) == .pass)
    }

    @Test("a direction table claims only its arms' axes")
    func tableClaimsItsAxes() {
        var r = router([
            GestureKey(.swipe4, Self.keys): .split([
                .left: LuaAction(lua: "a()"), .right: LuaAction(lua: "b()"),
            ])
        ])
        #expect(r.route(swipe(1, axis: Self.v, fingers: 4), now: 1) == .pass)
        #expect(r.route(swipe(1, axis: Self.h, fingers: 4), now: 2).swallow)
    }

    @Test("other keys, or a plain swipe, stay the Dock's")
    func plainSwipePasses() {
        var r = router([GestureKey(.swipe3, Self.keys): .family(.space)])
        #expect(
            r.route(swipe(1, axis: Self.h, fingers: 3, []), now: 1)
                == .pass
        )
        #expect(
            r.route(swipe(2, axis: Self.h, fingers: 3), now: 1.01)
                == .pass,
            "no begin was taken"
        )
        #expect(
            r.route(
                swipe(1, axis: Self.h, fingers: 3, [.control]),
                now: 2
            ) == .pass
        )
    }

    @Test("a binding with no keys never reaches the decision")
    func emptyChordNeverClaims() {
        let bindings: [GestureKey: GestureAction] = [
            GestureKey(.swipe3): .family(.space),
            GestureKey(.swipe4): .family(.focus),
            GestureKey(.spread): .run(LuaAction(lua: "a()")),
            GestureKey(.pinchTogether4): .run(LuaAction(lua: "b()")),
        ]
        let settings = GestureEventSettings(bindings: bindings)
        #expect(!settings.isOn)
        #expect(settings.chords.isEmpty)
        #expect(settings.swipeAxes.isEmpty)
        var r = router(bindings)
        for fingers in [0, 3, 4] {
            #expect(
                r.route(
                    swipe(1, axis: Self.h, fingers: fingers, []),
                    now: 1
                ) == .pass
            )
        }
        // Every consumed input needs a modifier at bind time too.
        for input: GestureInput in [
            .swipe3, .swipe4, .swipe5, .spread, .pinchTogether, .rotate,
            .spread4, .pinchTogether4,
        ] {
            #expect(GestureKey(input).refusal == .needsModifier, "\(input)")
        }
    }

    @Test("a four-finger pinch is claimed only for four fingers")
    func dockPinchNeedsFour() {
        var r = router([
            GestureKey(.spread4, Self.keys): .run(LuaAction(lua: "a()"))
        ])
        let pinch = GestureEventSample.dockPinch
        #expect(r.route(swipe(1, axis: pinch, fingers: 5), now: 1) == .pass)
        #expect(r.route(swipe(1, axis: pinch, fingers: 4), now: 2).swallow)
    }
}
