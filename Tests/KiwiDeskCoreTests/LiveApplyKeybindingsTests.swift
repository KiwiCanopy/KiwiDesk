import Foundation
import Testing

@testable import KiwiDeskCore

/// Live-apply for keybinding edits (#123 Part 1):
/// `liveApplyKeybindings(modes:)` re-registers the running
/// hotkeys from an edited, unsaved mode set — resolved through
/// the active profile's override, persisting nothing — and
/// `nil` re-registers from the saved sidecar (the Revert /
/// discard direction).
@Suite("Live-apply keybindings (#123)", .serialized)
@MainActor
struct LiveApplyKeybindingsTests {

    // MARK: - Helpers

    private func makeGuiCore() -> KiwiCore {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-liveapply-\(UUID().uuidString)"
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

    /// Base gui.json: one default-mode binding (alt+h).
    private func baseConfig() -> GuiConfig {
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    binding("alt+h", lua: "marker = \"base\"")
                ]
            )
        ]
        return config
    }

    private func registered(
        _ combo: String,
        mode: String = "default",
        core: KiwiCore
    ) throws -> Bool {
        let parsed = try #require(KeyCombo.parse(combo))
        return core.keys.bindings(for: mode)[parsed] != nil
    }

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

    // MARK: - Apply / revert directions

    @Test("Edited modes register live; gui.json untouched")
    func editedModesRegisterWithoutPersisting() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())

        var edited = baseConfig().modes
        edited[0].bindings.append(
            binding("alt+j", lua: "hit = true")
        )
        core.liveApplyKeybindings(modes: edited)

        #expect(
            try fire("alt+j", readGlobal: "hit", core: core)
                == .bool(true)
        )
        #expect(try registered("alt+h", core: core))
        // Nothing was persisted: the sidecar still holds only
        // the base binding.
        let saved = try #require(core.guiConfigStore.load())
        #expect(saved.modes == baseConfig().modes)
    }

    @Test("nil re-registers from the saved sidecar (revert)")
    func nilRevertsToSavedBindings() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())

        var edited = baseConfig().modes
        edited[0].bindings.append(
            binding("alt+j", lua: "hit = true")
        )
        core.liveApplyKeybindings(modes: edited)
        #expect(try registered("alt+j", core: core))

        core.liveApplyKeybindings(modes: nil)
        #expect(!(try registered("alt+j", core: core)))
        #expect(try registered("alt+h", core: core))
    }

    // MARK: - Profile override resolution

    @Test("Active profile's override wins over edited base")
    func profileOverrideResolves() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())
        try core.profiles.save(
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
                                    lua:
                                        "marker = \"override\""
                                )
                            ]
                        )
                    ]
                )
            )
        )
        #expect(
            core.execute(
                "load_profile",
                args: [.string("Work")]
            ).isSuccess
        )

        // Live-apply an edited BASE set: a new combo lands,
        // and the profile's rebind of alt+h still wins — the
        // exact registration a Save + reload would produce.
        var edited = baseConfig().modes
        edited[0].bindings.append(
            binding("alt+j", lua: "hit = true")
        )
        core.liveApplyKeybindings(modes: edited)

        #expect(
            try fire("alt+j", readGlobal: "hit", core: core)
                == .bool(true)
        )
        #expect(
            try fire("alt+h", readGlobal: "marker", core: core)
                == .string("override")
        )
    }

    // MARK: - Mode preservation

    @Test("Active non-default key mode survives a live-apply")
    func activeModeSurvives() throws {
        let core = makeGuiCore()
        var config = baseConfig()
        config.modes.append(
            KeyMode(
                name: "resize",
                bindings: [
                    binding("h", lua: "shrunk = true")
                ]
            )
        )
        try core.saveGuiConfig(config)

        core.keys.switchMode("resize")
        #expect(core.keys.currentMode == "resize")

        core.liveApplyKeybindings(modes: config.modes)
        #expect(core.keys.currentMode == "resize")
    }

    @Test("A live-apply that removes the active mode resets")
    func removedActiveModeFallsBack() throws {
        let core = makeGuiCore()
        var config = baseConfig()
        config.modes.append(
            KeyMode(
                name: "resize",
                bindings: [
                    binding("h", lua: "shrunk = true")
                ]
            )
        )
        try core.saveGuiConfig(config)
        core.keys.switchMode("resize")

        core.liveApplyKeybindings(modes: baseConfig().modes)
        #expect(core.keys.currentMode == "default")
    }
}
