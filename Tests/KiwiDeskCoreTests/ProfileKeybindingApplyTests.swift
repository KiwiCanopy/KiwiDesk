import Foundation
import Testing

@testable import KiwiDeskCore

/// Integration tests for the per-profile keybinding tier
/// (#55 phase 6): `apply(profile:)` re-registers keybindings
/// with the applied profile's `KeyModeOverride`, and the O4
/// soft base layer guarantees every base binding the profile
/// does not rebind stays live — the switch-key-trap invariant,
/// exercised end to end (profile JSON → apply → Carbon-less
/// registrar → Lua fire).
@Suite("Profile apply keybindings (#55 phase 6)", .serialized)
@MainActor
struct ProfileKeybindingApplyTests {

    // MARK: - Helpers

    private func makeGuiCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-profkeys-\(UUID().uuidString)"
                )
        )
        try? core.guiConfigStore.save(GuiConfig())
        return core
    }

    private func binding(
        _ combo: String,
        lua: String
    ) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: lua,
            kind: .custom,
            label: ""
        )
    }

    /// Base gui.json: a switch key (alt+p) and a rebindable
    /// combo (alt+h) in the default mode.
    private func baseConfig() -> GuiConfig {
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    binding(
                        "alt+p",
                        lua: "switched = \"base\""
                    ),
                    binding("alt+h", lua: "marker = \"base\""),
                ]
            )
        ]
        return config
    }

    /// A stored profile whose override rebinds ONLY alt+h.
    private func workProfile() -> Profile {
        Profile(
            name: "Work",
            monitorSets: [
                MonitorSet(monitors: ["A:100x100"])
            ],
            spaceModes: [:],
            settings: TilingSettings(),
            modes: KeyModeOverride(
                modes: [
                    KeyMode(
                        name: "default",
                        bindings: [
                            binding(
                                "alt+h",
                                lua: "marker = \"override\""
                            )
                        ]
                    )
                ]
            )
        )
    }

    /// Fires the registered ref for `combo` and returns the
    /// Lua global `name` afterwards.
    private func fire(
        _ combo: String,
        readGlobal name: String,
        core: KiwiCore
    ) throws -> LuaValue {
        let parsed = try #require(KeyCombo.parse(combo))
        let ref = try #require(
            core.keys.bindings(for: "default")[parsed]
        )
        let lua = try #require(core.lua)
        _ = lua.call(ref: ref)
        return lua.global(name)
    }

    // MARK: - O4 switch-key-trap invariant

    /// The profile rebinds one combo; every other base binding
    /// must still resolve — in particular the switch key, so a
    /// profile can never trap the user (O4 soft base layer).
    @Test("Override rebinds one combo; base survives (O4)")
    func overrideAppliesBaseSurvives() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())
        try core.profiles.save(workProfile())

        let result = core.execute(
            "load_profile",
            args: [.string("Work")]
        )
        #expect(result.isSuccess)

        // The rebound combo fires the OVERRIDE body.
        #expect(
            try fire("alt+h", readGlobal: "marker", core: core)
                == .string("override")
        )
        // The unmentioned switch key fires the BASE body —
        // no switch-key trap.
        #expect(
            try fire("alt+p", readGlobal: "switched", core: core)
                == .string("base")
        )
    }

    @Test("Profile without override reverts to base bindings")
    func plainProfileRevertsToBase() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())
        try core.profiles.save(workProfile())
        try core.profiles.save(
            Profile(
                name: "Plain",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )

        core.execute("load_profile", args: [.string("Work")])
        #expect(
            try fire("alt+h", readGlobal: "marker", core: core)
                == .string("override")
        )

        core.execute("load_profile", args: [.string("Plain")])
        #expect(
            try fire("alt+h", readGlobal: "marker", core: core)
                == .string("base")
        )
    }

    @Test("Reload keeps the active profile's override")
    func reloadKeepsActiveOverride() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())
        try core.profiles.save(workProfile())
        core.execute("load_profile", args: [.string("Work")])

        // reapplyActiveProfileState inside loadConfig must
        // re-register with the adopted profile's override.
        core.loadConfig()

        #expect(
            try fire("alt+h", readGlobal: "marker", core: core)
                == .string("override")
        )
    }

    // MARK: - O7 all-or-nothing ownership

    @Test("Not GUI-managed: apply(profile:) leaves Lua binds")
    func nonGuiManagedKeepsLuaBindings() throws {
        // No gui.json: Lua owns keybindings entirely.
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-profkeys-\(UUID().uuidString)"
                )
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let lua = """
            KiwiDesk.bind("alt+h", function()
                marker = "lua"
            end)
            """
        try lua.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        try core.profiles.save(workProfile())

        core.execute("load_profile", args: [.string("Work")])

        // The Lua-registered binding survives — the profile's
        // override is structured-config vocabulary and must
        // not touch Lua-owned bindings (O7).
        #expect(
            try fire("alt+h", readGlobal: "marker", core: core)
                == .string("lua")
        )
    }
}
