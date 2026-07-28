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

    /// Verifies exactly one ref per combo exists after
    /// loadConfig — structured loader resets stale-block refs.
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
        // A stale block (pre-#55) also binds alt+h on load.
        try writeInitLua(
            staleBlock(binding: "alt+h"),
            core: core
        )
        core.loadConfig()

        let combo = try #require(KeyCombo.parse("alt+h"))
        let bindings = core.keys.bindings(for: "default")
        // Pins re-registration: the structured entry is the
        // only one. The keyed dict cannot hold duplicates, so
        // the ref-leak half of the guard lives in
        // `noLeakedRefsAfterLoad` below.
        #expect(bindings[combo] != nil)
        #expect(bindings.count == 1)
    }

    /// Leak canary for an init.lua bind that duplicates a
    /// gui.json binding: the structured loader must release the
    /// init.lua ref so it does not accumulate. `luaL_ref` reuses
    /// released slots, so after `loadConfig()` the **second**
    /// probe must land on the same slot in a core whose init.lua
    /// holds the extra bind as in one whose init.lua is empty —
    /// that equality is the real no-leak invariant. The first
    /// probe must not shift *up* (a leaked ref would push it
    /// higher); whether it lands strictly lower depends on the
    /// release/re-register ordering, which #116 changed when it
    /// dropped managed-block recognition (a pre-#55 bind is now an
    /// ordinary foreign bind), so this asserts `<=`, not `<`.
    @Test("init.lua bind refs are released (slot-reuse canary)")
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

        // Block core: a stale pre-#55 block also binds alt+h
        // on load; its ref must be released by the reset.
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
}
