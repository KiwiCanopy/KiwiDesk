import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The bound buttons over a real core (#3281): the resolve hands
/// the tap its presses, a fired press runs its binding's Lua, a
/// swallowed left press reaches the press listeners it deafened,
/// and a side button steps a list the way it is named.
@Suite("Pointer button wiring", .serialized)
@MainActor
struct PointerButtonWiringTests {
    private func core() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-buttons-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "".write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    private func bind(_ core: KiwiCore, _ map: [GestureKey: GestureAction]) {
        core.applyGestures(
            base: GestureMap(map.mapValues(GestureEntry.bound)),
            profile: nil,
            scrollProfile: nil
        )
    }

    private func press(
        _ core: KiwiCore,
        _ key: GestureKey,
        _ phase: PointerButtonEvent.Phase = .pressed,
        direction: GestureDirection? = nil
    ) {
        core.mouse.pointer.receive(
            PointerTapDelivery(
                grab: [],
                buttons: [
                    PointerButtonEvent(
                        phase: phase,
                        key: key,
                        direction: direction,
                        location: CGPoint(x: 30, y: 40),
                        time: 0
                    )
                ],
                reenabled: false
            )
        )
    }

    @Test("the resolve hands the tap its bound presses")
    func resolveReachesTheTap() throws {
        let core = try core()
        #expect(!core.mouse.pointer.buttonSettings.isOn)
        bind(core, [GestureKey(.sideButtons): .family(.space)])
        let settings = core.mouse.pointer.buttonSettings
        #expect(settings.takes(.other(3), chord: []))
        #expect(settings.takes(.other(4), chord: []))
        #expect(!settings.takes(.other(3), chord: [.control]))
        var asked: [CGEventMask] = []
        core.mouse.pointer.makeTap = { mask, _ in
            asked.append(mask)
            return nil
        }
        core.mouse.pointer.stop()
        core.mouse.pointer.start()
        #expect(
            asked
                == [PointerConsumers.grabMask | PointerConsumers.buttonMask]
        )
    }

    @Test("a fired click runs its Lua and gives the press back")
    func clickRunsAndRedelivers() throws {
        let core = try core()
        let lua = try #require(core.keys.lua)
        // ⌃⌥ is the resize drag's, which holds those keys.
        let key = GestureKey(.click, [.control, .shift])
        bind(core, [key: .run(LuaAction(lua: "kiwi_clicked = true"))])
        var presses: [CGPoint] = []
        core.mouse.onLeftMouseDown = { point, _ in presses.append(point) }
        core.mouse.pointer.start()
        press(core, key)
        #expect(lua.global("kiwi_clicked") == .bool(true))
        #expect(presses == [GeometryUtils.axPoint(CGPoint(x: 30, y: 40))])
        #expect(core.mouse.press != nil)
        press(core, key, .released)
        // A release runs nothing of its own.
        _ = lua.run("kiwi_clicked = false")
        press(core, key, .released)
        #expect(lua.global("kiwi_clicked") == .bool(false))
    }

    @Test("a side button's split runs the arm it names")
    func sideButtonArm() throws {
        let core = try core()
        let lua = try #require(core.keys.lua)
        let key = GestureKey(.sideButtons)
        bind(
            core,
            [key: .split([.forward: LuaAction(lua: "kiwi_side = 4")])]
        )
        core.mouse.pointer.start()
        press(core, key, direction: .back)
        #expect(lua.global("kiwi_side") == .none)
        press(core, key, direction: .forward)
        #expect(lua.global("kiwi_side") == .number(4))
    }

    @Test("Back is the previous one, Forward the next, whatever list")
    func buttonsStepTheWayTheyAreNamed() {
        for family in [GestureFamily.space, .walk, .track] {
            #expect(family.stepsForward(.back) == false, "\(family)")
            #expect(family.stepsForward(.forward) == true, "\(family)")
        }
        let space = GestureFamily.space
        #expect(space.lua(.back) == "KiwiDesk.focus_space_previous()")
        #expect(space.lua(.forward) == "KiwiDesk.focus_space_next()")
        #expect(
            GestureFamily.focus.lua(.back) == "KiwiDesk.focus(\"left\")"
        )
        // The wheel keeps the list against the hand.
        #expect(GestureFamily.space.stepsForward(.up) == true)
    }

    @Test("a tap torn down mid-press ends the press through the front")
    func teardownEndsTheHeldPress() throws {
        let core = try core()
        let key = GestureKey(.click, [.control, .shift])
        bind(core, [key: .run(LuaAction(lua: "kiwi_clicked = true"))])
        core.mouse.pointer.makeTap = { _, _ in Tap() }
        core.mouse.pointer.start()
        press(core, key)
        #expect(core.mouse.pointer.buttonsHeld.count == 1)
        #expect(core.mouse.press?.upAt == nil)
        // The last button binding goes: the union shrinks and the
        // tap that held the release is rebuilt without it.
        bind(core, [:])
        #expect(core.mouse.pointer.buttonsHeld.isEmpty)
        // The press record closes with it.
        #expect(core.mouse.press?.upAt != nil)
    }

    @Test("Back focuses the window on the left on any layout")
    func backFocusesLeft() throws {
        let core = try core()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_300 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.state.workspaces.focus(WindowID(2), in: space)
        core.stepFamily(
            .focus,
            toward: .back,
            key: GestureKey(.sideButtons)
        )
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    private final class Tap: PointerTapHandle {
        func setSnapshot(_ snapshot: PointerTapSnapshot) {}
        func stop() {}
    }
}
