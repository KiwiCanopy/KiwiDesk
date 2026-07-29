import CoreGraphics
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
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-seed-\(UUID().uuidString)"
                )
        )
    }

    private func twoBySide(
        _ id: UInt32,
        name: String,
        x: CGFloat
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: 0, width: 1920, height: 1080)
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

    @Test("settings-bearing init.lua stays Lua-owned, no sidecar")
    func settingsBearingConfigUntouched() throws {
        let core = makeCore()
        // A `set_*` verb declares managed settings, so seeding a
        // default gui.json would silently override it (#354).
        try writeInitLua(
            "KiwiDesk.set_mode(1, \"stack\")\n",
            core: core
        )
        core.loadConfig()
        #expect(!core.guiConfigStore.exists)
        #expect(!core.isGuiManaged)
    }

    @Test("namespaced-setter init.lua stays Lua-owned, no sidecar")
    func namespacedSetterConfigUntouched() throws {
        let core = makeCore()
        // The common way to tune per-layout tiling is a namespace
        // verb (bsp/stack/scroll/…), not KiwiDesk.set_*. Seeding a
        // default gui.json would silently override it (#354).
        try writeInitLua(
            "bsp.set_ratio_h(0.6)\n",
            core: core
        )
        core.loadConfig()
        #expect(!core.guiConfigStore.exists)
        #expect(!core.isGuiManaged)
    }

    @Test("hooks-only init.lua still gets the GUI seed (#354)")
    func hooksOnlyConfigSeeds() throws {
        let core = makeCore()
        // The documented sketchybar bridge shape: event hooks +
        // control flow, no managed settings. Should still boot
        // GUI-managed with defaults, and the hooks are untouched.
        // The hook body execs `true`, not a real receiver: this
        // fixture *executes* (unlike the ManagedConfig string
        // analyses), and a `sketchybar --trigger` here spawned a
        // forever-blocked child on any host with the binary but
        // no daemon — the #489/#494 tail-hang root. Classification
        // only reads the shape, so the command is free to be inert.
        try writeInitLua(
            """
            for _, event in ipairs({ "space_change" }) do
                KiwiDesk.on(event, function()
                    KiwiDesk.exec("true")
                end)
            end
            """,
            core: core
        )
        core.loadConfig()
        #expect(core.guiConfigStore.exists)
        #expect(core.isGuiManaged)
    }

    @Test("comment-only init.lua gets the GUI seed (#354)")
    func commentOnlyConfigSeeds() throws {
        let core = makeCore()
        try writeInitLua("-- user config\n", core: core)
        core.loadConfig()
        #expect(core.guiConfigStore.exists)
        #expect(core.isGuiManaged)
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

    /// #270/#466: at first run macOS reports only the active
    /// Space, so the live list is just ["1"] — not empty, so the
    /// empty-state pad is skipped. The seed pads that bare
    /// signature to the per-display ladder anyway, so with two
    /// displays spaces 1–10 all exist and the top digit ⌃⌥0
    /// (= space 10) binds out of the box rather than only ⌃⌥1.
    @Test("partial first-run discovery pads to the ladder")
    func partialDiscoveryPadsToLadder() {
        let core = makeCore()
        core.state.apply(
            .displaysChanged([
                twoBySide(1, name: "Main", x: 0),
                twoBySide(2, name: "Second", x: 1920),
            ])
        )
        core.state.workspaces.ensureSpace(SpaceID("1"))

        let seed = core.guiConfigSeed()
        let spaces = Set(seed.spaces.map(\.raw))
        for n in 1...10 {
            #expect(spaces.contains("\(n)"), "missing space \(n)")
        }
        let base = seed.modes.first { $0.isDefault }
        #expect(
            (base?.bindings ?? []).contains {
                $0.combo == "control+option+0"
                    && $0.lua == "KiwiDesk.focus_space(\"10\")"
            },
            "⌃⌥0 not seeded despite two displays discovered"
        )
    }
}
