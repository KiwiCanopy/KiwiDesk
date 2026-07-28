import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Tests for `KiwiCore.applyStructuredConfig()` (#55 phase 4).
///
/// Double-registration proof: the structured loader calls
/// `keys.reset()` before re-registering, so managed-block refs
/// are released and exactly one set of refs exists after
/// `loadConfig()`. The proof test removes `init.lua`'s block
/// and shows bindings/rules still register correctly from
/// `gui.json` alone — demonstrating the structured path is
/// independent of the managed block.
@Suite("Structured config loader (#55 phase 4)", .serialized)
@MainActor
struct StructuredConfigTests {

    // MARK: - Helpers

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-struct-\(UUID().uuidString)"
                )
        )
    }

    /// GUI-managed core: gui.json sidecar exists.
    private func makeGuiCore() -> KiwiCore {
        let core = makeCore()
        try? core.guiConfigStore.save(GuiConfig())
        return core
    }

    /// Write `content` to init.lua, replacing whatever was there.
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

    // MARK: - Rules applied without managed block

    /// Proof test: gui.json rules reach live state even when
    /// init.lua is empty (managed block absent — phase-5 state).
    @Test(
        "app, float, and ignore rules load from gui.json"
    )
    func structuredRulesNoBlock() throws {
        let core = makeGuiCore()
        var config = GuiConfig()
        config.appRules = ["spotify": SpaceID("music")]
        config.floatRules = ["com.apple.calculator"]
        config.ignoreRules = ["io.tailscale.ipn.macos"]
        // Write gui.json; init.lua stays empty (hooks-only).
        try core.saveGuiConfig(config)
        try writeInitLua("", core: core)

        core.loadConfig()

        #expect(
            core.state.appRules["spotify"] == SpaceID("music")
        )
        #expect(
            core.eventLoop.floatRules.rawRules
                == ["com.apple.calculator"]
        )
        #expect(
            core.eventLoop.ignoreRules.matches(
                bundleID: "io.tailscale.ipn.macos"
            )
        )
    }

    // MARK: - Keybindings without managed block

    /// Proof test: keybinding registered via structured loader
    /// (init.lua empty) — structured path is independent.
    @Test(
        "keybinding from gui.json registers without init.lua block"
    )
    func structuredBindingNoBlock() throws {
        let core = makeGuiCore()
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "-- noop",
                        kind: .custom,
                        label: "test"
                    )
                ]
            )
        ]
        try core.saveGuiConfig(config)
        try writeInitLua("", core: core)

        core.loadConfig()

        let combo = try #require(KeyCombo.parse("alt+h"))
        #expect(
            core.keys.bindings(for: "default")[combo] != nil
        )
    }

    // MARK: - Mode icon preserved

    @Test("Named mode icon preserved through structured loader")
    func namedModeIconPreserved() throws {
        let core = makeGuiCore()
        var config = GuiConfig()
        config.modes = [
            KeyMode(name: "default", bindings: []),
            KeyMode(
                name: "resize",
                icon: "📐",
                bindings: [
                    KeyBinding(
                        combo: "alt+l",
                        lua: "-- noop",
                        kind: .custom,
                        label: ""
                    )
                ]
            ),
        ]
        try core.saveGuiConfig(config)
        try writeInitLua("", core: core)
        core.loadConfig()

        #expect(core.keys.icon(for: "resize") == "📐")
    }

    // MARK: - Not GUI-managed: structured loader is no-op

    @Test("Non-GUI-managed core: structured loader is no-op")
    func nonGuiManagedIsNoop() throws {
        // A core with no gui.json is not GUI-managed.
        let core = makeCore()
        var config = GuiConfig()
        config.appRules = ["xcode": SpaceID("code")]
        // Write ONLY init.lua (no gui.json sidecar).
        try writeInitLua("app_rules = {}", core: core)
        // Manually set state to check it isn't overwritten.
        core.state.appRules = [
            "shouldsurvive": SpaceID("1")
        ]
        core.applyStructuredConfig()
        // Structured loader must be a no-op — state unchanged.
        #expect(
            core.state.appRules["shouldsurvive"]
                == SpaceID("1")
        )
        #expect(core.state.appRules["xcode"] == nil)
    }

    // MARK: - Hand-written bind in init.lua (O6)

    /// A `KiwiDesk.bind` in init.lua binding `combo` — it still
    /// executes on load, but must stay inert in effect: the
    /// structured loader resets its refs and re-registers from
    /// gui.json. (Formerly a pre-#55 managed block; the marker
    /// recognition was removed in #116 — the bind is what the
    /// loader-reset behavior turns on, not the surrounding
    /// comments.)
    private func staleBlock(binding combo: String) -> String {
        """
        KiwiDesk.bind("\(combo)", function()
            -- noop
        end)
        """
    }

    /// A `KiwiDesk.bind` in init.lua makes the config Lua-owned
    /// (`isGuiManaged` false, #116: a bind is a foreign token), so
    /// gui.json is not structure-loaded and the init.lua bind is
    /// the sole registration — exactly one ref per combo, no
    /// double. (The structured loader's own ref reset is guarded by
    /// `structuredReloadReleasesRefs` below, which keeps the config
    /// GUI-managed.)
    @Test("Only one ref per combo after loadConfig (no double)")
    func noDoubleRegistration() throws {
        let core = makeGuiCore()
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "-- noop",
                        kind: .custom,
                        label: ""
                    )
                ]
            )
        ]
        try core.saveGuiConfig(config)
        // A hand-written bind in init.lua binds alt+h on load,
        // and (being foreign) makes the config Lua-owned.
        try writeInitLua(
            staleBlock(binding: "alt+h"),
            core: core
        )
        core.loadConfig()

        let combo = try #require(KeyCombo.parse("alt+h"))
        let bindings = core.keys.bindings(for: "default")
        // The init.lua bind is the only registration (gui.json is
        // ignored while Lua-owned); the keyed dict cannot hold
        // duplicates. The structured ref-reset guard lives in
        // `structuredReloadReleasesRefs` below.
        #expect(bindings[combo] != nil)
        #expect(bindings.count == 1)
    }

    /// No-leak canary comparing a Lua-owned core (a `KiwiDesk.bind`
    /// in init.lua, #116) against a GUI-managed core with the same
    /// gui.json and an empty init.lua. Each registers one live
    /// keybinding ref, so the registry must not diverge: `luaL_ref`
    /// reuses released slots, so the **second** probe must land on
    /// the same slot in both (the real no-leak invariant), and the
    /// first must never shift *up* (a leaked ref would). `<=`, not
    /// `<`: both cores now reach the same high-water mark, where a
    /// pre-#116 managed block would have freed a slot the loader
    /// reused first. (The structured loader's own reload reset is
    /// guarded by `structuredReloadReleasesRefs`.)
    @Test("init.lua bind refs do not leak (slot-reuse canary)")
    func noLeakedRefsAfterLoad() throws {
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "-- noop",
                        kind: .custom,
                        label: ""
                    )
                ]
            )
        ]

        // Baseline: same gui.json, init.lua empty (no block).
        let bare = makeGuiCore()
        try bare.saveGuiConfig(config)
        try writeInitLua("", core: bare)
        bare.loadConfig()
        let bareLua = try #require(bare.lua)
        let bareProbe =
            try bareLua
            .makeFunction(body: "-- probe").get()
        let bareSecondProbe =
            try bareLua
            .makeFunction(body: "-- second probe").get()

        // Block core: an init.lua bind registers alt+h (Lua-owned).
        let block = makeGuiCore()
        try block.saveGuiConfig(config)
        try writeInitLua(
            staleBlock(binding: "alt+h"),
            core: block
        )
        block.loadConfig()
        let blockLua = try #require(block.lua)
        let blockProbe =
            try blockLua
            .makeFunction(body: "-- probe").get()
        let blockSecondProbe =
            try blockLua
            .makeFunction(body: "-- second probe").get()

        // No leak: the block core's ref is released, so its probe
        // never shifts up (a leak would). The second probes must
        // match exactly — that is the invariant.
        #expect(blockProbe <= bareProbe)
        #expect(blockSecondProbe == bareSecondProbe)
    }

    /// The structured loader's transactional reset: reloading a
    /// GUI-managed config (empty init.lua, so it stays managed)
    /// must release the prior load's binding refs before
    /// re-registering, so the registry does not grow across
    /// reloads. This is the live `applyStructuredConfig` path —
    /// after #116 no init.lua bind can drive it (a bind is foreign
    /// → Lua-owned), so a reload is what exercises the reset.
    @Test("Reloading a GUI-managed config releases prior refs")
    func structuredReloadReleasesRefs() throws {
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "-- noop",
                        kind: .custom,
                        label: ""
                    )
                ]
            )
        ]
        let core = makeGuiCore()
        try core.saveGuiConfig(config)
        try writeInitLua("", core: core)  // hooks-only → GUI-managed
        core.loadConfig()  // first structured load
        let afterFirst =
            try #require(core.lua)
            .makeFunction(body: "-- probe").get()
        core.loadConfig()  // reload: release prior, re-register
        let afterReload =
            try #require(core.lua)
            .makeFunction(body: "-- probe").get()
        // No accumulation: the reload released the prior ref, so
        // the probe does not climb across reloads.
        #expect(afterReload <= afterFirst)
    }
}
