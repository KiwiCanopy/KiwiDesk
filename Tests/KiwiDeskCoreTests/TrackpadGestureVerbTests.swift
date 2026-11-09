import Foundation
import Testing

@testable import KiwiDeskCore

/// `trackpad_gesture.bind` and the one resolve home (#1873): the
/// verb writes the base, a profile's override outranks it, and a
/// recognized gesture runs its action as a shortcut press.
@Suite("Trackpad gesture verbs", .serialized)
@MainActor
struct TrackpadGestureVerbTests {
    private static let hyper: ScrollChord = [.control, .option]

    private func bind(
        _ core: KiwiCore,
        _ args: [String]
    ) -> CommandResponse {
        core.execute("trackpad_gesture.bind", args: args.map { .string($0) })
    }

    @Test("bind writes the base and the resolved bindings")
    func bindWrites() {
        let core = makeTestCore()
        #expect(bind(core, ["swipe4", "swap", "control+option"]).isSuccess)
        let binding = TrackpadGestureBinding(
            action: "swap",
            modifiers: Self.hyper
        )
        #expect(core.mouse.trackpad.base[.swipe4] == .bound(binding))
        #expect(core.mouse.trackpad.bindings[.swipe4] == binding)
    }

    @Test("no action is None: a seed turns off")
    func emptyIsNone() {
        let core = makeTestCore()
        #expect(core.mouse.trackpad.bindings[.tap4] != nil, "seeded")
        #expect(bind(core, ["tap4"]).isSuccess)
        #expect(core.mouse.trackpad.base[.tap4] == .unbound)
        #expect(core.mouse.trackpad.bindings[.tap4] == nil)
    }

    @Test("an unknown slot, family or modifier, or none, is refused")
    func refusals() {
        let core = makeTestCore()
        let bad: [[String]] = [
            ["tap9", "x()"],
            ["swipe3", "fly", "control"],
            ["swipe3", "focus"],
            ["rotate", "x()"],
            ["tap3", "x()", "control+fn"],
        ]
        for args in bad {
            #expect(!bind(core, args).isSuccess, "\(args)")
        }
        #expect(core.mouse.trackpad.base.isEmpty)
    }

    @Test("a profile's override outranks the base the verb wrote")
    func profileOutranks() {
        let core = makeTestCore()
        core.applyTrackpadGestures(
            base: TrackpadGestureMap(),
            profile: TrackpadGestureMap([.tap3: .unbound])
        )
        #expect(bind(core, ["tap3", "KiwiDesk.cycle_mode()"]).isSuccess)
        #expect(core.mouse.trackpad.bindings[.tap3] == nil)
        core.applyTrackpadGestures(profile: nil)
        #expect(
            core.mouse.trackpad.bindings[.tap3]?.action
                == "KiwiDesk.cycle_mode()",
            "the verb's base survives the profile leaving"
        )
    }

    @Test("a config's base and a profile reach the front together")
    func behaviorOverridesCarryIt() {
        let core = makeTestCore()
        var config = GuiConfig()
        config.trackpadGesture = TrackpadGestureMap([.tap4: .unbound])
        var profile = Profile(
            name: "P",
            monitorSets: [],
            spaceModes: [:],
            settings: TilingSettings()
        )
        profile.trackpadGesture = TrackpadGestureMap([
            .tap5: .bound(.init(action: "KiwiDesk.cycle_mode()"))
        ])
        core.applyBehaviorOverrides(base: config, profile: profile)
        #expect(core.mouse.trackpad.bindings[.tap4] == nil)
        #expect(core.mouse.trackpad.bindings[.tap5] != nil)
    }

    @Test("a swipe family takes the swipe's direction")
    func familiesTakeTheDirection() {
        func lua(_ family: String, _ direction: Direction) -> String? {
            KiwiCore.trackpadGestureLua(
                TrackpadGestureBinding(action: family),
                TrackpadGestureEvent(
                    kind: .swipe(direction),
                    fingers: 3,
                    modifiers: [],
                    time: 0
                )
            )
        }
        #expect(lua("focus", .left) == "KiwiDesk.focus(\"left\")")
        #expect(lua("swap", .down) == "KiwiDesk.swap(\"down\")")
        #expect(
            lua("display", .right) == "KiwiDesk.focus_display(\"right\")"
        )
        #expect(lua("track", .up) == "KiwiDesk.move_to_track(\"prev\")")
        #expect(lua("track", .right) == "KiwiDesk.move_to_track(\"next\")")
        #expect(lua("space", .left) == "KiwiDesk.focus_space_next()")
        #expect(lua("space", .right) == "KiwiDesk.focus_space_previous()")
        #expect(lua("fly", .left) == nil)
    }

    @Test("a recognized tap runs its Lua through the wired handler")
    func tapRunsItsAction() throws {
        let core = makeTestCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        core.keys.lua = lua
        var opened = 0
        core.uiBridge.onOpenSettings = { opened += 1 }
        #expect(bind(core, ["tap5", "KiwiDesk.open_settings()"]).isSuccess)
        core.mouse.trackpad.start()
        defer { core.mouse.trackpad.stop() }
        core.mouse.trackpad.receive([
            TrackpadGestureEvent(
                kind: .tap,
                fingers: 5,
                modifiers: [],
                time: 0
            )
        ])
        #expect(opened == 1)
    }
}
