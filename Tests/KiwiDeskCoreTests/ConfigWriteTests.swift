import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-cfg-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// A model exercising every global + profile-scoped section.
private func richConfig() -> GuiConfig {
    var config = GuiConfig()
    config.settings.gapsGlobal = Gaps(
        outer: Gaps.Outer(top: 4, bottom: 8, left: 12, right: 16),
        inner: Gaps.Inner(horizontal: 6, vertical: 2)
    )
    config.settings.gapsOverride[SpaceID("browser")] =
        .uniform(0)
    config.settings.minWindowSize = 250
    config.settings.bsp.splitRatioH = 0.62
    config.settings.bsp.strategy = .alternating
    config.settings.stack.masterCount = 2
    config.settings.scrolling.slotSize = .points(900)
    config.settings.grid.columns = 4
    config.settings.grid.rows = 3
    config.settings.monocle.appBar.thickness = 40
    config.settings.monocle.appBar.textColor = "#112233"
    config.settings.dragCornerRadius = 12
    config.settings.mouseResize = .snapBack
    config.settings.animations.onSpaceChange = true
    config.settings.animations.onScrolling = false
    config.settings.placementOverride[SpaceID("mail")] = .last
    config.spaces = [
        SpaceID(1), SpaceID("browser"), SpaceID("mail"),
        SpaceID("music"),
    ]
    config.spaceModes = [
        SpaceID(1): .stack, SpaceID("music"): .floating,
    ]
    config.appRules = ["spotify": SpaceID("music")]
    config.floatRules = ["Calculator", "Finder:Get Info"]
    config.profileBindings = [2: "Studio"]
    config.modes = [
        KeyMode(
            name: "default",
            bindings: [
                KeyBinding(
                    combo: "alt+h",
                    lua: "KiwiDesk.focus(\"left\")",
                    kind: .navigation,
                    label: "Focus left"
                )
            ]
        ),
        KeyMode(
            name: "resize",
            icon: "📐",
            bindings: [
                KeyBinding(
                    combo: "alt+l",
                    lua: "KiwiDesk.resize(20)",
                    kind: .custom,
                    label: "Grow"
                )
            ]
        ),
    ]
    return config
}

/// Round-trip and KiwiCore-level config tests (#55: saves go
/// to `gui.json` only; `init.lua` is hooks-only, never
/// generated). Split/detection tests live in
/// `ManagedConfigTests`.
@Suite("Config write-back", .serialized)
@MainActor
struct ConfigWriteTests {
    @Test("saveGuiConfig never touches init.lua (hooks-only)")
    func saveLeavesInitLua() throws {
        let core = makeCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let hooks = "-- my hooks file\n"
        try hooks.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )

        try core.saveGuiConfig(richConfig())

        let after = try String(
            contentsOf: core.configURL,
            encoding: .utf8
        )
        #expect(after == hooks)
    }

    @Test("round-trip: write, reload, live state matches")
    func roundTrip() throws {
        let core = makeCore()
        let config = richConfig()
        try core.saveGuiConfig(config)
        core.applyProfileScopedState(from: config)

        #expect(core.tiler.settings == config.settings)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .stack
        )
        #expect(
            core.state.workspaces[SpaceID("music")]?.mode
                == .floating
        )
        #expect(core.state.appRules["spotify"] == SpaceID("music"))
        #expect(core.nativeSpaceBindings[2] == "Studio")
        #expect(core.keys.icon(for: "resize") == "📐")
        let combo = KeyCombo.parse("alt+h")
        #expect(combo != nil)
        if let combo {
            #expect(
                core.keys.bindings(for: "default")[combo] != nil
            )
        }
    }

    @Test("reopening reads back the saved model")
    func sidecarRoundTrip() throws {
        let core = makeCore()
        let config = richConfig()
        try core.saveGuiConfig(config)
        // The sidecar holds the globals; the profile-scoped
        // fields overlay from live state, so applying them
        // first makes the round-trip lossless.
        core.applyProfileScopedState(from: config)
        let reloaded = core.loadGuiConfig()
        #expect(reloaded == config)
    }

    @Test("deleting entries clears them on reload")
    func deletionRoundTrip() throws {
        let core = makeCore()
        let config = richConfig()
        try core.saveGuiConfig(config)
        core.applyProfileScopedState(from: config)
        #expect(core.state.appRules["spotify"] != nil)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .stack
        )

        // Save a config with all sparse entries removed.
        try core.saveGuiConfig(GuiConfig())
        core.applyProfileScopedState(from: GuiConfig())

        #expect(core.state.appRules.isEmpty)
        #expect(core.eventLoop.floatRules.rawRules.isEmpty)
        #expect(core.tiler.settings.gapsOverride.isEmpty)
        #expect(core.tiler.settings.placementOverride.isEmpty)
        #expect(core.nativeSpaceBindings.isEmpty)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .bsp
        )
    }

    @Test("fractional ratios survive a profile round-trip")
    func fractionalRoundTrip() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.settings.bsp.splitRatioH = 1.0 / 3.0
        config.settings.bsp.splitRatioV = 1.0 / 6.0
        config.settings.stack.masterRatio = 2.0 / 7.0
        core.applyProfileScopedState(from: config)
        try core.persistProfile(named: "ratios")
        let saved = try core.profiles.read(name: "ratios")
        #expect(saved.settings.bsp.splitRatioH == 1.0 / 3.0)
        #expect(saved.settings.bsp.splitRatioV == 1.0 / 6.0)
        #expect(
            saved.settings.stack.masterRatio == 2.0 / 7.0
        )
    }

    @Test("adopt migrates a hand-written config into the GUI")
    func adoptIntoGui() throws {
        let core = makeCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let handwritten = """
            KiwiDesk.set_gap_global(7)
            KiwiDesk.set_mode(1, "stack")
            KiwiDesk.bind("cmd+h", function()
                KiwiDesk.focus("left")
            end)
            """
        try handwritten.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(core.configHasForeignCode)

        try core.adoptConfigIntoGui()

        // Now GUI-managed: no foreign code, sidecar written.
        #expect(!core.configHasForeignCode)
        #expect(core.guiConfigStore.exists)
        // Executed settings carried into the adopted state.
        #expect(core.tiler.settings.gapsGlobal.outer.top == 7)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .stack
        )
        // Original preserved verbatim as a comment; NO managed
        // block is generated — init.lua is hooks-only (#55),
        // so no active Lua remains in the file.
        let file = try String(
            contentsOf: core.configURL,
            encoding: .utf8
        )
        #expect(file.contains("-- KiwiDesk.bind(\"cmd+h\""))
        #expect(!file.contains(ManagedConfig.beginMarker))
        for line in file.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(
                in: .whitespaces
            )
            #expect(t.isEmpty || t.hasPrefix("--"))
        }
        // Keybindings are recovered from the original file into
        // gui.json (#4) and registered by the structured loader
        // — the combo is live again after adopt.
        let combo = try #require(KeyCombo.parse("cmd+h"))
        #expect(core.keys.bindings(for: "default")[combo] != nil)
    }
}
