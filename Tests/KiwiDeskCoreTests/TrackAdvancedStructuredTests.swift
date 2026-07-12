import Foundation
import Testing

@testable import KiwiDeskCore

/// The advanced-track gate's config plumbing (#181): the
/// `track_advanced` sidecar global, the inert-keybinding
/// registration filter, and the round-trip shape.
@Suite("Advanced-track structured config (#181)", .serialized)
@MainActor
struct TrackAdvancedStructuredTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-track-gate-\(UUID().uuidString)"
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

    /// A default mode holding one gated row and one plain row.
    private func modesWithGatedRow() -> [KeyMode] {
        [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+m",
                        lua:
                            "KiwiDesk.move_to_track(\"prev\")",
                        kind: .navigation,
                        label: "Move window to previous track"
                    ),
                    KeyBinding(
                        combo: "alt+f",
                        lua: "KiwiDesk.focus(\"left\")",
                        kind: .navigation,
                        label: "Focus window to the left"
                    ),
                ]
            )
        ]
    }

    @Test("track_advanced applies from gui.json")
    func sidecarApplies() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.trackAdvanced = true
        try core.guiConfigStore.save(config)
        try writeInitLua("", core: core)
        core.loadConfig()
        #expect(core.isTrackAdvanced)
    }

    @Test("Gated rows register only while the gate is on")
    func inertRegistration() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.modes = modesWithGatedRow()
        try core.guiConfigStore.save(config)
        try writeInitLua("", core: core)
        core.loadConfig()

        let gated = try #require(KeyCombo.parse("alt+m"))
        let plain = try #require(KeyCombo.parse("alt+f"))
        let off = core.keys.bindings(for: "default")
        // Off: the gated row is inert (skipped), never pruned
        // — the sidecar row survives untouched.
        #expect(off[gated] == nil)
        #expect(off[plain] != nil)
        #expect(
            core.guiConfigStore.load()?.modes.first?
                .bindings.count == 2
        )

        // The toggle re-registers without a reload.
        core.execute(
            "set_track_advanced",
            args: [.bool(true)]
        )
        let on = core.keys.bindings(for: "default")
        #expect(on[gated] != nil)
        #expect(on[plain] != nil)

        core.execute(
            "set_track_advanced",
            args: [.bool(false)]
        )
        #expect(
            core.keys.bindings(for: "default")[gated] == nil
        )
    }

    @Test("Lua-set flag survives adoption into the seed")
    func luaFlagSeeds() throws {
        let core = makeCore()
        try writeInitLua(
            "KiwiDesk.set_track_advanced(true)",
            core: core
        )
        core.loadConfig()
        #expect(core.isTrackAdvanced)
        #expect(core.guiConfigSeed().trackAdvanced)
        // And a reload without the call falls back to OFF —
        // the flag is declarative, not sticky.
        try writeInitLua("", core: core)
        core.loadConfig()
        #expect(!core.isTrackAdvanced)
    }

    @Test("set_track_advanced in init.lua is managed vocabulary")
    func managedVocabulary() {
        #expect(
            ManagedConfig.hasForeignCode(
                "KiwiDesk.set_track_advanced(true)"
            )
        )
    }

    @Test("track_advanced round-trips; missing key = off")
    func coding() throws {
        var config = GuiConfig()
        config.trackAdvanced = true
        let data = try JSONEncoder().encode(config)
        let json =
            try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"track_advanced\":true"))
        let back = try JSONDecoder().decode(
            GuiConfig.self,
            from: data
        )
        #expect(back.trackAdvanced)
        let missing = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data("{}".utf8)
        )
        #expect(!missing.trackAdvanced)
    }
}
