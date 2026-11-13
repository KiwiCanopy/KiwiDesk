import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pointer tap's button decision (#3281): a press a binding
/// takes is swallowed and fires, its drags and its release are
/// swallowed with it, and a press no binding takes passes, its
/// release too.
@Suite("Pointer tap buttons")
struct PointerTapButtonTests {
    private static let keys: ScrollChord = [.control, .option]
    private static let lua = LuaAction(lua: "KiwiDesk.focus(\"left\")")

    private func router(
        _ resolved: [GestureKey: GestureAction]
    ) -> PointerTapRouter {
        var router = PointerTapRouter()
        router.snapshot = PointerTapSnapshot(
            grab: nil,
            buttons: PointerButtonSettings(resolved: resolved)
        )
        return router
    }

    private func sample(
        _ kind: PointerSample.Kind,
        _ chord: ScrollChord = keys
    ) -> PointerSample {
        PointerSample(kind: kind, location: CGPoint(x: 4, y: 5), chord: chord)
    }

    @Test("a bound side button is swallowed, fires once, owns its up")
    func boundPressIsSwallowed() {
        var r = router([GestureKey(.sideButtons): .family(.space)])
        let down = r.route(sample(.buttonDown(.other(3)), []), now: 1)
        #expect(down.swallow)
        #expect(down.buttons.map(\.phase) == [.pressed])
        #expect(down.buttons.first?.key == GestureKey(.sideButtons))
        #expect(down.buttons.first?.direction == .back)
        let drag = r.route(sample(.buttonDragged(.other(3)), []), now: 2)
        #expect(drag.swallow)
        #expect(drag.buttons.isEmpty)
        let up = r.route(sample(.buttonUp(.other(3)), []), now: 3)
        #expect(up.swallow)
        #expect(up.buttons.map(\.phase) == [.released])
        // The stream is over: the next release is the app's.
        #expect(r.route(sample(.buttonUp(.other(3)), []), now: 4) == .pass)
    }

    @Test("an unbound press passes, and so does its release")
    func unboundPressPasses() {
        var r = router([GestureKey(.sideButtons): .family(.space)])
        // Other keys than the binding's.
        let held = r.route(sample(.buttonDown(.other(3))), now: 1)
        #expect(held == .pass)
        #expect(r.route(sample(.buttonUp(.other(3))), now: 2) == .pass)
        // A button no input names.
        #expect(r.route(sample(.buttonDown(.other(5)), []), now: 3) == .pass)
        // A right-click with no binding.
        #expect(r.route(sample(.buttonDown(.right)), now: 4) == .pass)
        // Nothing bound at all.
        var off = PointerTapRouter()
        #expect(off.route(sample(.buttonDown(.other(4)), []), now: 5) == .pass)
    }

    @Test("a split takes only the buttons it binds")
    func splitTakesItsArms() {
        var r = router([
            GestureKey(.sideButtons): .split([.forward: Self.lua])
        ])
        #expect(r.route(sample(.buttonDown(.other(3)), []), now: 1) == .pass)
        let forward = r.route(sample(.buttonDown(.other(4)), []), now: 2)
        #expect(forward.swallow)
        #expect(forward.buttons.first?.direction == .forward)
    }

    @Test("a bound click swallows its press, drags and release")
    func boundClickOwnsTheLeftStream() {
        var r = router([GestureKey(.click, Self.keys): .run(Self.lua)])
        let down = r.route(sample(.leftDown), now: 1)
        #expect(down.swallow)
        #expect(down.buttons.first?.key == GestureKey(.click, Self.keys))
        // The keys may change before the release; it is still ours.
        #expect(r.route(sample(.leftDragged, []), now: 2).swallow)
        let up = r.route(sample(.leftUp, []), now: 3)
        #expect(up.swallow)
        #expect(up.buttons.map(\.phase) == [.released])
        // A plain click passes.
        #expect(r.route(sample(.leftDown, []), now: 4) == .pass)
        #expect(r.route(sample(.leftUp, []), now: 5) == .pass)
    }

    @Test("each button maps to its input")
    func buttonsMapToInputs() {
        #expect(PointerButton.left.gesture?.input == .click)
        #expect(PointerButton.right.gesture?.input == .rightClick)
        #expect(PointerButton.other(2).gesture?.input == .wheelClick)
        #expect(PointerButton.other(3).gesture?.direction == .back)
        #expect(PointerButton.other(4).gesture?.direction == .forward)
        #expect(PointerButton.other(5).gesture == nil)
    }

    @Test("a re-enable ends a held press with no location")
    func reseedReleasesHeldButtons() {
        var r = router([GestureKey(.wheelClick): .run(Self.lua)])
        _ = r.route(sample(.buttonDown(.other(2)), []), now: 1)
        let routed = r.reseed(now: 2)
        #expect(routed.buttons.map(\.phase) == [.released])
        #expect(routed.buttons.first?.location == nil)
        #expect(r.route(sample(.buttonUp(.other(2)), []), now: 3) == .pass)
    }

    @Test("the clicks and the side buttons are fired inputs")
    func buttonsAreFired() {
        for input: GestureInput in [
            .click, .rightClick, .wheelClick, .sideButtons,
        ] {
            #expect(input.isFired, "\(input)")
            #expect(input.isButton, "\(input)")
        }
        #expect(GestureInput.click.needsModifier)
        #expect(GestureInput.rightClick.needsModifier)
        #expect(!GestureInput.wheelClick.needsModifier)
        #expect(!GestureInput.sideButtons.needsModifier)
        #expect(GestureInput(rawValue: "wheel_click") == .wheelClick)
        #expect(GestureInput(rawValue: "middle_click") == nil)
    }

    @Test("a bound button is decided while a grab owns the stream")
    func buttonsAheadOfTheGrab() {
        var r = router([GestureKey(.sideButtons): .family(.space)])
        r.snapshot.grab = .defaults
        let grab = r.route(sample(.leftDown, [.control, .command]), now: 1)
        #expect(grab.grab.first?.phase == .began)
        let back = r.route(sample(.buttonDown(.other(3)), []), now: 2)
        #expect(back.swallow)
        #expect(back.buttons.first?.direction == .back)
        // The grab still owns its stream.
        let drag = r.route(
            sample(.leftDragged, [.control, .command]),
            now: 3
        )
        #expect(drag.grab.first?.phase == .moved)
    }

    @Test("a click on a hover grab's keys ends the grab and fires")
    func clickEndsAHoverGrab() {
        let keys: ScrollChord = [.control, .shift]
        var r = router([GestureKey(.click, keys): .run(Self.lua)])
        r.snapshot.grab = ModifierDragSettings(
            resolved: [GestureKey(.hoverMove, keys): .grab(.move)]
        )
        let move = r.route(sample(.mouseMoved, keys), now: 1)
        #expect(move.grab.first?.phase == .began)
        let click = r.route(sample(.leftDown, keys), now: 2)
        #expect(click.grab.first?.phase == .ended)
        #expect(click.swallow)
        #expect(click.buttons.first?.key == GestureKey(.click, keys))
    }
}
