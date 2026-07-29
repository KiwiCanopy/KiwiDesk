import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The two reset escape hatches (#634). Tier 2 injects a hard
/// delete for `trash` so a run never fills the real Trash.
@Suite("Reset escape hatches", .serialized)
@MainActor
struct ResetEscapeHatchTests {
    @Test("Discard removes both snapshot files and the memory")
    func discardArrangement() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-reset-\(UUID().uuidString)"
            )
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        core.onLog = { _ in }
        core.crash.captureState = { [weak core] in
            core?.state.snapshot()
        }
        core.crash.autosave()
        // A clean shutdown would write the session file; write
        // it directly through the same store.
        core.crash.shutdownCleanly()
        core.crash.autosave()
        let marker = dir.appendingPathComponent(
            ".state_snapshot"
        )
        let session = dir.appendingPathComponent(
            ".session_snapshot"
        )
        let files = FileManager.default
        #expect(files.fileExists(atPath: marker.path))
        #expect(files.fileExists(atPath: session.path))

        // The two in-memory halves: a remembered window→space
        // association and a wake snapshot held for replay.
        core.state.remember(WindowID(9), in: SpaceID("gone"))
        core.sleepWake.restoreDelayMS = 0
        core.sleepWake.systemWillRest()

        core.discardSavedArrangement()
        #expect(!files.fileExists(atPath: marker.path))
        #expect(!files.fileExists(atPath: session.path))
        #expect(
            core.state.rememberedSpace(of: WindowID(9)) == nil
        )
        // The held snapshot is gone, so the return leg has
        // nothing to replay — `systemDidReturn` bails on its
        // synchronous guard, before any delayed task exists.
        var replayed = false
        core.sleepWake.restoreState = { _ in replayed = true }
        core.sleepWake.systemDidReturn()
        #expect(!replayed)
    }

    @Test("Reset reseeds first-launch state and keeps init.lua")
    func resetReseedsFirstLaunch() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-reset-\(UUID().uuidString)"
            )
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        core.onLog = { _ in }
        // A user config: custom Lua, a tuned setting, an extra
        // space, and a saved profile.
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let luaMarker = "-- my precious hooks\n"
        try luaMarker.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.state.workspaces.ensureSpace(SpaceID("poison"))
        core.tiler.settings.gapsGlobal.outer.top = 42
        core.execute(
            "save_profile",
            args: [.string("Poisoned")]
        )

        core.resetAllSettings(trash: {
            try FileManager.default.removeItem(at: $0)
        })

        // The sidecar reseeded, the poisoned space and profile
        // gone, factory settings back, init.lua untouched.
        #expect(core.guiConfigStore.exists)
        let spaces = core.state.workspaces.allSpaces.map(\.id)
        #expect(!spaces.contains(SpaceID("poison")))
        #expect(!core.profiles.list().contains("Poisoned"))
        // First-launch state is the starter ladder's tuning
        // (the Starter profile seed applies it), not bare
        // TilingSettings() — derive from the one source.
        #expect(
            core.tiler.settings.gapsGlobal
                == StarterLadder.settings().gapsGlobal
        )
        #expect(
            try String(
                contentsOf: core.configURL,
                encoding: .utf8
            ) == luaMarker
        )
        let sidecar = core.guiConfigStore.load()
        #expect(sidecar?.spaces.isEmpty == false)
        #expect(
            Set(sidecar?.spaces ?? []) == Set(spaces)
        )
    }

    /// The forget-proof half of the reset↔first-launch mirror:
    /// `guiConfigSeed` captures LIVE state, and the reset
    /// hand-clears only part of it (settings, pins, spaces)
    /// while relying on `loadConfig`'s ordering for the rest
    /// (rule bases, keybindings, bindings). Any future field
    /// the seed captures live and the reset forgets — or a
    /// `loadConfig` reorder that moves the seed before a
    /// clear — shows up here as an inequality against a virgin
    /// first launch, instead of shipping silently.
    @Test("Reset equals a virgin first launch, field for field")
    func resetMatchesFirstLaunch() throws {
        let files = FileManager.default
        func tempDir() throws -> URL {
            let dir = files.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-reset-\(UUID().uuidString)"
                )
            try files.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            return dir
        }

        // Virgin: a plain first launch on an empty dir.
        let virginDir = try tempDir()
        defer { try? files.removeItem(at: virginDir) }
        let virgin = makeTestCore(configDirectory: virginDir)
        virgin.onLog = { _ in }
        virgin.loadConfig()
        let virginData = try Data(
            contentsOf: virgin.guiConfigStore.url
        )

        // Poisoned: same first launch, then mutations across
        // the families the seed captures live — an extra space,
        // a mode, tuned settings, a keybinding mode, rules, a
        // profile — then the reset.
        let dir = try tempDir()
        defer { try? files.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        core.onLog = { _ in }
        core.loadConfig()
        var config = core.loadGuiConfig()
        config.spaces.append(SpaceID("poison"))
        config.spaceModes[SpaceID("poison")] = .stack
        config.floatRules.append("com.example.poison")
        config.appRules["com.example.app"] = SpaceID("poison")
        var mode = KeyMode.defaultMode
        mode.name = "poison-mode"
        config.modes.append(mode)
        try core.saveGuiConfig(config)
        core.tiler.settings.gapsGlobal.outer.top = 42
        core.execute(
            "save_profile",
            args: [.string("Poisoned")]
        )

        core.resetAllSettings(trash: {
            try FileManager.default.removeItem(at: $0)
        })
        let resetData = try Data(
            contentsOf: core.guiConfigStore.url
        )
        // Byte-equal: both files came from the same encoder on
        // the same host displays, so any field-level leak is a
        // diff.
        #expect(resetData == virginData)
        #expect(core.profiles.list() == virgin.profiles.list())
    }

    @Test("A Lua-owned reset never grafts the starter ladder")
    func luaOwnedResetSkipsLadder() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-reset-\(UUID().uuidString)"
            )
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let core = makeTestCore(configDirectory: dir)
        core.onLog = { _ in }
        // A Lua-owned config: declares managed settings, so no
        // sidecar and no ladder ever seed for it.
        let lua = "KiwiDesk.set_gap_global(5)\n"
        try lua.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        core.state.workspaces.ensureSpace(SpaceID("poison"))
        // A settings field the Lua config does NOT declare: on
        // this path no starter ladder re-stamps the settings,
        // so the reset's own factory clear is the only thing
        // between this value and the "fresh" state — the
        // GUI-managed equivalence test cannot see that clear.
        core.tiler.settings.animations.durationMS = 999

        core.resetAllSettings(trash: {
            try FileManager.default.removeItem(at: $0)
        })
        #expect(
            core.tiler.settings.animations.durationMS
                == AnimationSettings().durationMS
        )
        let spaces = core.state.workspaces.allSpaces.map(\.id)
        #expect(!spaces.contains(SpaceID("poison")))
        // First launch of this config is the single default
        // space — five-per-display starter spaces would be a
        // state no first launch ever shows.
        #expect(spaces == [SpaceID(1)])
        #expect(!core.guiConfigStore.exists)
        #expect(
            try String(
                contentsOf: core.configURL,
                encoding: .utf8
            ) == lua
        )
    }
}
