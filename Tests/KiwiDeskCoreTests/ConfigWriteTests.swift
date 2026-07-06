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

/// A model exercising every section the writer emits.
private func richConfig() -> GuiConfig {
    var config = GuiConfig()
    config.settings.gapsGlobal = Gaps(
        outer: Gaps.Outer(top: 4, bottom: 8, left: 12, right: 16),
        inner: Gaps.Inner(horizontal: 6, vertical: 2)
    )
    config.settings.gapsOverride[SpaceID("browser")] =
        .uniform(0)
    config.settings.minWindowSize = 250
    config.settings.bsp.splitRatio = 0.62
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
    config.spaceModes = [
        SpaceID(1): .stack, SpaceID("music"): .floating,
    ]
    config.appRules = ["Spotify": SpaceID("music")]
    config.spaceMonitorMap = [
        SpaceID(1): ["LG:2560x1440"],
        SpaceID("music"): ["Dell:1920x1080"],
    ]
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

@Suite("Config write-back", .serialized)
@MainActor
struct ConfigWriteTests {
    @Test("managed block splits and preserves user code")
    func managedSplit() {
        let source = """
            -- my own comment
            KiwiDesk.debug_log("hi")

            \(ManagedConfig.beginMarker)
            KiwiDesk.set_gap_global(10)
            \(ManagedConfig.endMarker)

            KiwiDesk.debug_log("after")
            """
        let split = ManagedConfig.split(source)
        #expect(split.managed?.contains("set_gap_global") == true)
        #expect(split.before.contains("my own comment"))
        #expect(split.after.contains("after"))
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("comment-only files carry no foreign code")
    func noForeignCode() {
        let source = """
            -- just a comment
            \(ManagedConfig.beginMarker)
            KiwiDesk.set_gap_global(10)
            \(ManagedConfig.endMarker)
            """
        #expect(!ManagedConfig.hasForeignCode(source))
    }

    @Test("merge replaces the block, keeps the surroundings")
    func mergeReplaces() {
        let original = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(10)",
            into: "-- header\n"
        )
        let updated = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(20)",
            into: original
        )
        #expect(updated.contains("set_gap_global(20)"))
        #expect(!updated.contains("set_gap_global(10)"))
        #expect(updated.contains("-- header"))
    }

    @Test("gap writer collapses uniform values to a number")
    func uniformGaps() {
        var settings = TilingSettings()
        settings.gapsGlobal = .uniform(10)
        let lua = LuaConfigWriter.gaps(settings)
        #expect(lua.contains("set_gap_global(10)"))
        #expect(!lua.contains("top ="))
    }

    @Test(
        "default mode never emits an icon; other modes do"
    )
    func defaultModeHasNoIcon() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(combo: "alt+h", lua: "-- noop")
                ]
            ),
            KeyMode(
                name: "resize",
                icon: "📐",
                bindings: [
                    KeyBinding(combo: "alt+l", lua: "-- noop")
                ]
            ),
        ]
        let lua = LuaConfigWriter.keybindings(modes)
        #expect(lua.contains("KiwiDesk.bind(\"alt+h\""))
        #expect(lua.contains("icon = \"📐\""))
        // The default mode's block never carries an icon
        // argument — only `KiwiDesk.bind`, no `define_mode`.
        #expect(!lua.contains("define_mode(\"default\""))
    }

    @Test(
        "a malformed default mode icon is dropped, not emitted"
    )
    func defaultModeIconIsDropped() {
        let modes = [
            KeyMode(
                name: KeyMode.defaultName,
                icon: "📐",
                bindings: [
                    KeyBinding(combo: "alt+h", lua: "-- noop")
                ]
            )
        ]
        let lua = LuaConfigWriter.keybindings(modes)
        #expect(lua.contains("KiwiDesk.bind(\"alt+h\""))
        #expect(!lua.contains("icon ="))
        #expect(!lua.contains("define_mode"))
    }

    @Test("space_monitor_map emits a table; empty is omitted")
    func spaceMonitorMapWriter() {
        let map: [SpaceID: [String]] = [
            SpaceID(1): ["LG:2560x1440"],
            SpaceID("music"): ["Dell:1920x1080"],
        ]
        let lua = LuaConfigWriter.spaceMonitorMap(map)
        #expect(lua.contains("space_monitor_map = {"))
        #expect(lua.contains("[\"1\"] = { \"LG:2560x1440\" },"))
        #expect(
            lua.contains(
                "[\"music\"] = { \"Dell:1920x1080\" },"
            )
        )
        #expect(LuaConfigWriter.spaceMonitorMap([:]).isEmpty)
        // A space with an empty chain contributes nothing.
        #expect(
            LuaConfigWriter.spaceMonitorMap(
                [SpaceID(1): []]
            ).isEmpty
        )
    }

    @Test("round-trip: write, reload, live state matches")
    func roundTrip() throws {
        let core = makeCore()
        let config = richConfig()
        try core.saveGuiConfig(config)

        #expect(core.tiler.settings == config.settings)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .stack
        )
        #expect(
            core.state.workspaces[SpaceID("music")]?.mode
                == .floating
        )
        #expect(core.state.appRules["Spotify"] == SpaceID("music"))
        #expect(
            core.spaceMonitorMap[SpaceID(1)] == ["LG:2560x1440"]
        )
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

    @Test("reopening reads back the saved sidecar verbatim")
    func sidecarRoundTrip() throws {
        let core = makeCore()
        let config = richConfig()
        try core.saveGuiConfig(config)
        let reloaded = core.loadGuiConfig()
        #expect(reloaded == config)
    }

    @Test("deleting entries clears them on reload")
    func deletionRoundTrip() throws {
        let core = makeCore()
        try core.saveGuiConfig(richConfig())
        #expect(core.state.appRules["Spotify"] != nil)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .stack
        )

        // Save a config with all sparse entries removed.
        try core.saveGuiConfig(GuiConfig())

        #expect(core.state.appRules.isEmpty)
        #expect(core.spaceMonitorMap.isEmpty)
        #expect(core.eventLoop.floatRules.rawRules.isEmpty)
        #expect(core.tiler.settings.gapsOverride.isEmpty)
        #expect(core.tiler.settings.placementOverride.isEmpty)
        #expect(core.nativeSpaceBindings.isEmpty)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .bsp
        )
    }

    @Test("fractional ratios survive write and reload exactly")
    func fractionalRoundTrip() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.settings.bsp.splitRatio = 1.0 / 3.0
        config.settings.stack.masterRatio = 2.0 / 7.0
        try core.saveGuiConfig(config)
        #expect(
            core.tiler.settings.bsp.splitRatio == 1.0 / 3.0
        )
        #expect(
            core.tiler.settings.stack.masterRatio == 2.0 / 7.0
        )
    }

    @Test("merge tolerates CRLF and keeps one block")
    func crlfMerge() {
        let source =
            "-- header\r\n" + ManagedConfig.beginMarker
            + "\r\nKiwiDesk.set_gap_global(10)\r\n"
            + ManagedConfig.endMarker + "\r\n"
        #expect(ManagedConfig.split(source).managed != nil)
        let merged = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(20)",
            into: source
        )
        let begins =
            merged.components(
                separatedBy: ManagedConfig.beginMarker
            ).count - 1
        #expect(begins == 1)
        #expect(merged.contains("set_gap_global(20)"))
        #expect(!merged.contains("set_gap_global(10)"))
    }

    @Test("merge strips an orphaned begin marker")
    func orphanMarker() {
        let source =
            "-- header\n" + ManagedConfig.beginMarker
            + "\nKiwiDesk.set_gap_global(10)\n"
        let merged = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(20)",
            into: source
        )
        let begins =
            merged.components(
                separatedBy: ManagedConfig.beginMarker
            ).count - 1
        #expect(begins == 1)
        #expect(merged.contains("-- header"))
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
        // Executed settings carried into the managed block.
        #expect(core.tiler.settings.gapsGlobal.outer.top == 7)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .stack
        )
        // Original preserved verbatim as a comment.
        let file = try String(
            contentsOf: core.configURL,
            encoding: .utf8
        )
        #expect(file.contains("-- KiwiDesk.bind(\"cmd+h\""))
        // Keybindings are recovered from the original file and
        // re-emitted into the managed block, so the combo is live
        // again after adopt — normalized to its canonical form
        // (#4). The commented backup above still uses the
        // hand-written "cmd+h".
        #expect(file.contains("KiwiDesk.bind(\"command+h\""))
        let combo = try #require(KeyCombo.parse("cmd+h"))
        #expect(core.keys.bindings(for: "default")[combo] != nil)
    }
}
