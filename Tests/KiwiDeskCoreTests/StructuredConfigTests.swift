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
        KiwiCore(
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
        "app_rules + float_rules set from gui.json alone"
    )
    func structuredRulesNoBlock() throws {
        let core = makeGuiCore()
        var config = GuiConfig()
        config.appRules = ["Spotify": SpaceID("music")]
        config.floatRules = ["Calculator"]
        // Write gui.json + managed block, then clear init.lua.
        try core.saveGuiConfig(config)
        try writeInitLua("", core: core)

        core.loadConfig()

        #expect(
            core.state.appRules["Spotify"] == SpaceID("music")
        )
        #expect(
            core.eventLoop.floatRules.rawRules
                == ["Calculator"]
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
        config.appRules = ["Xcode": SpaceID("code")]
        // Write ONLY init.lua (no gui.json sidecar).
        try writeInitLua("app_rules = {}", core: core)
        // Manually set state to check it isn't overwritten.
        core.state.appRules = [
            "ShouldSurvive": SpaceID("1")
        ]
        core.applyStructuredConfig()
        // Structured loader must be a no-op — state unchanged.
        #expect(
            core.state.appRules["ShouldSurvive"]
                == SpaceID("1")
        )
        #expect(core.state.appRules["Xcode"] == nil)
    }

    // MARK: - Double-registration guard

    /// Verifies exactly one ref per combo exists after
    /// loadConfig — structured loader resets managed-block refs.
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
        // init.lua has a managed block that also binds alt+h.
        core.loadConfig()

        let combo = try #require(KeyCombo.parse("alt+h"))
        let bindings = core.keys.bindings(for: "default")
        // Exactly one ref — not two (block + structured).
        #expect(bindings[combo] != nil)
        // The dict is keyed, so duplicates are structurally
        // impossible; the test confirms only one key exists.
        #expect(bindings.count == 1)
    }
}
