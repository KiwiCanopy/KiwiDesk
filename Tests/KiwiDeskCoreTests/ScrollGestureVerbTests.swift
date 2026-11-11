import Foundation
import Testing

@testable import KiwiDeskCore

/// `scroll_gesture.*` and the one resolve home (#1656): verbs write
/// the base, a profile's override outranks it, and the tap is
/// configured with the resolved value.
@Suite("Scroll gesture verbs", .serialized)
@MainActor
struct ScrollGestureVerbTests {
    private func tapChords(_ core: KiwiCore) -> ScrollGestureSettings {
        core.mouse.scroll.settings
    }

    @Test("Natural scrolling is a boolean or \"system\" on the base")
    func naturalScrolling() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!tapChords(core).naturalTrackpad)
        #expect(!tapChords(core).naturalMouse)
        #expect(
            core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.bool(true), .string("mouse")]
            ).isSuccess
        )
        #expect(!tapChords(core).naturalTrackpad)
        #expect(tapChords(core).naturalMouse)
        #expect(
            core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.string("system"), .string("trackpad")]
            ).isSuccess
        )
        #expect(core.mouse.scroll.base.naturalTrackpad == .system)
        #expect(
            !core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.string("no")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "scroll_gesture.set_natural_scrolling",
                args: [.bool(true), .string("pen")]
            ).isSuccess
        )
    }

    @Test("gesture.bind refuses a click or hover_move on a drag's keys")
    func bindRefusesAShadowedRow() {
        let core = makeTestCore()
        let hover = core.execute(
            "gesture.bind",
            args: [
                .string("hover_move"), .string("control+option"),
                .string("move"),
            ]
        )
        #expect(!hover.isSuccess)
        #expect(
            core.mouse.gestures.base[
                GestureKey(.hoverMove, [.control, .option])
            ]
                == nil
        )
        let free = core.execute(
            "gesture.bind",
            args: [
                .string("hover_move"), .string("option+command"),
                .string("move"),
            ]
        )
        #expect(free.isSuccess)
        #expect(
            core.mouse.pointer.grabSettings.bindings.contains(
                ModifierDragBinding(
                    .move,
                    chord: [.option, .command],
                    start: .hover
                )
            )
        )
    }

    @Test("a locked swipe keeps its axis and its sign")
    func lockedKeepsTheAxis() {
        var event = ScrollGestureEvent(
            chord: [.control, .option],
            kind: .changed,
            input: .trackpad,
            delta: CGVector(dx: 2, dy: -9),
            momentum: false,
            location: .zero,
            time: 0
        )
        #expect(event.locked(horizontal: nil).delta == event.delta)
        #expect(event.locked(horizontal: true).delta == CGVector(dx: 2, dy: 0))
        #expect(
            event.locked(horizontal: false).delta == CGVector(dx: 0, dy: -9)
        )
        event.momentum = true
        #expect(event.locked(horizontal: true).delta == event.delta)
    }

    @Test("a long family swipe's later steps keep the latched axis")
    func familyStepKeepsTheAxis() {
        var meter = ScrollStepMeter(longSwipes: true, distance: 60)
        func event(
            _ kind: ScrollGestureEvent.Kind,
            dx: CGFloat = 0,
            dy: CGFloat = 0
        ) -> ScrollGestureEvent {
            ScrollGestureEvent(
                chord: [.control, .option],
                kind: kind,
                input: .trackpad,
                delta: CGVector(dx: dx, dy: dy),
                momentum: false,
                location: .zero,
                time: 0
            )
        }
        #expect(KiwiCore.familyStep(&meter, event(.began)) == nil)
        let first = KiwiCore.familyStep(&meter, event(.changed, dx: 30))
        #expect(first?.0 == 1 && first?.1 == .right)
        // A diagonal frame: its larger axis is the other one.
        let diagonal = KiwiCore.familyStep(
            &meter,
            event(.changed, dx: 5, dy: -70)
        )
        #expect(diagonal == nil)
        let next = KiwiCore.familyStep(&meter, event(.changed, dx: 60))
        #expect(next?.0 == 1 && next?.1 == .right)
    }

    @Test("gesture.bind refuses a drag over a live hover_move")
    func dragRefusedOverHover() {
        let core = makeTestCore()
        let keys: [JSONValue] = [.string("option+command")]
        #expect(
            core.execute(
                "gesture.bind",
                args: [.string("hover_move")] + keys + [.string("move")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "gesture.bind",
                args: [.string("drag")] + keys + [.string("resize")]
            ).isSuccess
        )
    }
}
