import Foundation
import Testing

@testable import KiwiDeskCore

/// The first-run seed path (#91): a truly fresh install (no
/// init.lua, no gui.json) boots GUI-managed with the starter
/// shortcuts persisted and registered; anything the user (or
/// Lua) already authored is never touched.
@Suite("First-run shortcut seed (#91)", .serialized)
@MainActor
struct FirstRunSeedTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-seed-\(UUID().uuidString)"
                )
        )
    }

    private func writeInitLua(
        _ content: String,
        core: KiwiCore
    ) throws {
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try content.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    @Test("fresh install boots GUI-managed with seeded set")
    func freshInstallSeeds() {
        let core = makeCore()
        core.loadConfig()

        #expect(core.guiConfigStore.exists)
        #expect(core.isGuiManaged)
        let config = core.guiConfigStore.load()
        let base = config?.modes.first { $0.isDefault }
        #expect(base?.bindings.isEmpty == false)
        // Every seeded per-space row targets a space that is
        // in the seeded list — no dead rows (#91).
        let spaces = Set((config?.spaces ?? []).map(\.raw))
        for row in base?.bindings ?? []
        where row.lua.contains("_space") {
            let quoted = spaces.contains {
                row.lua.contains(SpaceLuaArg.quote($0))
            }
            #expect(quoted, "dead space row: \(row.lua)")
        }
    }

    @Test("fresh install registers the seeded binds live")
    func freshInstallRegisters() {
        let core = makeCore()
        core.loadConfig()
        // The structured loader ran on the seeded sidecar; the
        // default mode's combos are Carbon-parseable and bound.
        #expect(
            !core.keys.bindings(
                for: KeybindingManager.defaultMode
            ).isEmpty
        )
    }

    @Test("existing init.lua: no sidecar is created")
    func existingConfigUntouched() throws {
        let core = makeCore()
        try writeInitLua("-- user config\n", core: core)
        core.loadConfig()
        #expect(!core.guiConfigStore.exists)
    }

    @Test("existing sidecar survives a reload unchanged")
    func existingSidecarUntouched() throws {
        let core = makeCore()
        var config = GuiConfig()
        var mode = KeyMode.defaultMode
        mode.bindings = [
            KeyBinding(
                combo: "control+option+r",
                lua: "KiwiDesk.reload_config()",
                kind: .custom,
                label: ""
            )
        ]
        config.modes = [mode]
        try core.guiConfigStore.save(config)
        core.loadConfig()

        let loaded = core.guiConfigStore.load()
        let base = loaded?.modes.first { $0.isDefault }
        #expect(base?.bindings.count == 1)
        #expect(
            base?.bindings.first?.lua
                == "KiwiDesk.reload_config()"
        )
    }

    @Test("guiConfigSeed never seeds over Lua-authored binds")
    func luaBindingsBlockSeed() throws {
        let core = makeCore()
        try writeInitLua(
            """
            KiwiDesk.bind("ctrl+alt+r", function()
                KiwiDesk.reload_config()
            end)
            """,
            core: core
        )
        core.loadConfig()

        let seed = core.guiConfigSeed()
        let base = seed.modes.first { $0.isDefault }
        // The recovered Lua bind is the only row — the seed
        // guard saw an authored binding and stayed out.
        #expect(base?.bindings.count == 1)
        #expect(
            !(base?.bindings ?? []).contains {
                $0.lua == "KiwiDesk.focus(\"left\")"
            }
        )
    }

    @Test("guiConfigSeed seeds when Lua declares no binds")
    func bindingFreeLuaSeeds() throws {
        let core = makeCore()
        try writeInitLua(
            "KiwiDesk.set_gap_global(12)\n",
            core: core
        )
        core.loadConfig()

        let seed = core.guiConfigSeed()
        let base = seed.modes.first { $0.isDefault }
        #expect(
            (base?.bindings ?? []).contains {
                $0.lua == "KiwiDesk.focus(\"left\")"
            }
        )
    }
}
