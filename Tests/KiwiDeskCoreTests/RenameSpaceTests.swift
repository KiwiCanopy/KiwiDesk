import Foundation
import Testing

@testable import KiwiDeskCore

/// `GuiConfig.renameSpace` must migrate every place a SpaceID is
/// referenced (#13): the list, modes, app rules, the monitor
/// pins and Main role, and the space-targeting Lua inside
/// keybindings.
@Suite("Space rename migration")
struct RenameSpaceTests {
    private func richConfig() -> GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID("2"), SpaceID("mail")]
        config.spaceModes = [SpaceID("2"): .stack]
        config.appRules = ["Spotify": SpaceID("2")]
        config.spacePins = [SpaceID("2"): "LG:2560x1440"]
        config.mainSpaces = [SpaceID("mail")]
        config.settings.gapsOverride[SpaceID("2")] = .uniform(12)
        config.settings.placementOverride[SpaceID("2")] = .last
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+1",
                        lua: "KiwiDesk.focus_space(\"2\")",
                        kind: .navigation
                    ),
                    KeyBinding(
                        combo: "alt+2",
                        lua:
                            "KiwiDesk.move_to_space(\"2\")",
                        kind: .navigation
                    ),
                    KeyBinding(
                        combo: "alt+3",
                        lua:
                            "KiwiDesk."
                            + "move_to_space_and_follow"
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
            config.spacePins[SpaceID("main")]
                == "LG:2560x1440"
        )
        #expect(config.spacePins[SpaceID("2")] == nil)
        let lua = config.modes[0].bindings.map(\.lua)
        #expect(
            lua.contains(
                "KiwiDesk.focus_space(\"main\")"
            )
        )
        #expect(
            lua.contains(
                "KiwiDesk.move_to_space(\"main\")"
            )
        )
        #expect(
            lua.contains(
                "KiwiDesk.move_to_space_and_follow"
                    + "(\"main\")"
            )
        )
    }

    @Test("rename migrates per-layout overrides (#17)")
    func migratesLayoutOverrides() {
        var config = GuiConfig()
        config.spaces = [SpaceID("a"), SpaceID("b")]
        var bsp = BspOverride()
        bsp.splitRatioH = 0.3
        config.settings.bsp.override[SpaceID("a")] = bsp
        var grid = GridOverride()
        grid.columns = 4
        config.settings.grid.override[SpaceID("a")] = grid
        let ok = config.renameSpace(
            from: SpaceID("a"),
            to: SpaceID("c")
        )
        #expect(ok)
        #expect(
            config.settings.bsp.override[SpaceID("c")]?
                .splitRatioH == 0.3
        )
        #expect(
            config.settings.grid.override[SpaceID("c")]?
                .columns == 4
        )
        #expect(
            config.settings.bsp.override[SpaceID("a")] == nil
        )
    }

    @Test("rename migrates per-space gap and placement overrides")
    func migratesOverrides() {
        var config = richConfig()
        _ = config.renameSpace(
            from: SpaceID("2"),
            to: SpaceID("main")
        )
        #expect(
            config.settings.gapsOverride[SpaceID("main")]
                == .uniform(12)
        )
        #expect(
            config.settings.gapsOverride[SpaceID("2")] == nil
        )
        #expect(
            config.settings.placementOverride[SpaceID("main")]
                == .last
        )
        #expect(
            config.settings.placementOverride[SpaceID("2")] == nil
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

    @Test("rename to an empty name is rejected")
    func rejectsEmpty() {
        var config = richConfig()
        let ok = config.renameSpace(
            from: SpaceID("2"),
            to: SpaceID("")
        )
        #expect(!ok)
        #expect(config.spaces == [SpaceID("2"), SpaceID("mail")])
    }

    @Test("decode drops empty-named spaces and their entries")
    func decodeDropsEmptyNames() throws {
        var config = GuiConfig()
        config.spaces = [SpaceID(""), SpaceID("1")]
        config.appRules = ["Mail": SpaceID("")]
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(
            GuiConfig.self,
            from: data
        )
        #expect(decoded.spaces == [SpaceID("1")])
        #expect(decoded.appRules.isEmpty)
    }

    @Test("rename moves the Main role with the space")
    func migratesMainRole() {
        var config = richConfig()
        _ = config.renameSpace(
            from: SpaceID("mail"),
            to: SpaceID("inbox")
        )
        #expect(!config.mainSpaces.contains(SpaceID("mail")))
        #expect(config.mainSpaces.contains(SpaceID("inbox")))
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

/// `GuiConfig.fallbackSpace` (#68) and `SpaceID.deduplicated`
/// (#75). `deduplicated` was hoisted from `GuiConfig` to
/// `SpaceID` (Models) so `Profile` and `GuiConfig` share one
/// helper.
@Suite("GuiConfig space-order helpers")
struct GuiConfigSpaceOrderTests {
    @Test("rename migrates the fallback-space reference")
    func renameMigratesFallback() {
        var config = GuiConfig()
        config.spaces = [SpaceID("a"), SpaceID("b")]
        config.fallbackSpace = SpaceID("b")
        let ok = config.renameSpace(
            from: SpaceID("b"),
            to: SpaceID("c")
        )
        #expect(ok)
        #expect(config.fallbackSpace == SpaceID("c"))
    }

    @Test("rename of another space keeps the fallback")
    func renameKeepsUnrelatedFallback() {
        var config = GuiConfig()
        config.spaces = [SpaceID("a"), SpaceID("b")]
        config.fallbackSpace = SpaceID("b")
        let ok = config.renameSpace(
            from: SpaceID("a"),
            to: SpaceID("c")
        )
        #expect(ok)
        #expect(config.fallbackSpace == SpaceID("b"))
    }

    @Test("deduplicated preserves insertion order, no sort")
    func deduplicatedOrder() {
        let result = SpaceID.deduplicated([
            SpaceID("z"), SpaceID("a"), SpaceID("m"),
            SpaceID("z"),  // duplicate — dropped
        ])
        // Order is z, a, m — NOT sorted alphabetically.
        #expect(
            result == [SpaceID("z"), SpaceID("a"), SpaceID("m")]
        )
    }
}
