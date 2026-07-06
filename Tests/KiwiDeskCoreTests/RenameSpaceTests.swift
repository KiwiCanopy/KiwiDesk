import Testing

@testable import KiwiDeskCore

/// `GuiConfig.renameSpace` must migrate every place a SpaceID is
/// referenced (#13): the list, modes, app rules, the monitor map,
/// and the space-targeting Lua inside keybindings.
@Suite("Space rename migration")
struct RenameSpaceTests {
    private func richConfig() -> GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID("2"), SpaceID("mail")]
        config.spaceModes = [SpaceID("2"): .stack]
        config.appRules = ["Spotify": SpaceID("2")]
        config.spaceMonitorMap = [SpaceID("2"): ["LG:2560x1440"]]
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+1",
                        lua: "KiwiDesk.focus_virtual_space(\"2\")",
                        kind: .navigation
                    ),
                    KeyBinding(
                        combo: "alt+2",
                        lua:
                            "KiwiDesk.move_to_virtual_space(\"2\")",
                        kind: .navigation
                    ),
                    KeyBinding(
                        combo: "alt+3",
                        lua:
                            "KiwiDesk."
                            + "move_to_virtual_space_and_follow"
                            + "(\"2\")",
                        kind: .navigation
                    ),
                ]
            )
        ]
        return config
    }

    @Test("rename migrates every reference")
    func migratesAll() {
        var config = richConfig()
        let ok = config.renameSpace(
            from: SpaceID("2"),
            to: SpaceID("main")
        )
        #expect(ok)
        #expect(config.spaces == [SpaceID("main"), SpaceID("mail")])
        #expect(config.spaceModes[SpaceID("main")] == .stack)
        #expect(config.spaceModes[SpaceID("2")] == nil)
        #expect(config.appRules["Spotify"] == SpaceID("main"))
        #expect(
            config.spaceMonitorMap[SpaceID("main")]
                == ["LG:2560x1440"]
        )
        #expect(config.spaceMonitorMap[SpaceID("2")] == nil)
        let lua = config.modes[0].bindings.map(\.lua)
        #expect(
            lua.contains(
                "KiwiDesk.focus_virtual_space(\"main\")"
            )
        )
        #expect(
            lua.contains(
                "KiwiDesk.move_to_virtual_space(\"main\")"
            )
        )
        #expect(
            lua.contains(
                "KiwiDesk.move_to_virtual_space_and_follow"
                    + "(\"main\")"
            )
        )
    }

    @Test("the _and_follow call is not corrupted by the plain one")
    func followVariantIntact() {
        var config = richConfig()
        _ = config.renameSpace(
            from: SpaceID("2"),
            to: SpaceID("main")
        )
        // No binding should keep the old id in any variant.
        for binding in config.modes[0].bindings {
            #expect(!binding.lua.contains("\"2\""))
        }
    }

    @Test("rename to an existing id is rejected")
    func rejectsCollision() {
        var config = richConfig()
        let ok = config.renameSpace(
            from: SpaceID("2"),
            to: SpaceID("mail")
        )
        #expect(!ok)
        // Untouched.
        #expect(config.spaces == [SpaceID("2"), SpaceID("mail")])
        #expect(config.spaceModes[SpaceID("2")] == .stack)
    }

    @Test("rename of an unknown space is a no-op")
    func rejectsUnknown() {
        var config = richConfig()
        let ok = config.renameSpace(
            from: SpaceID("nope"),
            to: SpaceID("x")
        )
        #expect(!ok)
        #expect(config.spaces == [SpaceID("2"), SpaceID("mail")])
    }

    @Test("renaming to the same id succeeds trivially")
    func sameIdNoop() {
        var config = richConfig()
        let ok = config.renameSpace(
            from: SpaceID("2"),
            to: SpaceID("2")
        )
        #expect(ok)
        #expect(config.spaceModes[SpaceID("2")] == .stack)
    }
}
