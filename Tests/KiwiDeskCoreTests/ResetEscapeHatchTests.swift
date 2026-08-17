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
        core.sleepWake.systemWillRest(.direct)
        #expect(core.sleepWake.holdsSnapshot)

        core.discardSavedArrangement()
        #expect(!files.fileExists(atPath: marker.path))
        #expect(!files.fileExists(atPath: session.path))
        #expect(
            core.state.rememberedSpace(of: WindowID(9)) == nil
        )
        // The held-state probe, not a "nothing replayed" spy:
        // a surviving snapshot's replay hides behind an awaited
        // Task, so a synchronous spy assert passes even when
        // the drop is broken (review round 2).
        #expect(!core.sleepWake.holdsSnapshot)
    }

    /// The palettes survive a reset, which is the whole reason
    /// the action is named "Reset All **Settings**" rather than a
    /// total reset — `GeneralSection+Reset`'s doc comment and
    /// `docs/design-decisions.md` both rest the naming on it.
    ///
    /// It needs its own assertion since #606: the exemption used
    /// to be structural, a hard-coded two-element list, and is now
    /// an argument the caller passes. `[.guiConfig, .profiles]` →
    /// `ConfigArtifact.allCases` is a one-token edit that deletes
    /// a user's whole palette library, and nothing in this suite
    /// mentioned palettes at all (`code-reviewer`, 2026-08-17).
    @Test("Reset keeps the palette library, which names the action")
    func resetKeepsPalettes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-reset-pal-\(UUID().uuidString)"
            )
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        core.onLog = { _ in }
        try core.guiConfigStore.save(GuiConfig())
        try core.paletteLibrary.save(
            ColorPalette(
                name: "Mine",
                colors: [ColorPaletteKeys.all[0]: "#112233"]
            )
        )

        core.resetAllSettings(trash: {
            try FileManager.default.removeItem(at: $0)
        })

        #expect(
            core.paletteLibrary.userPalettes().map(\.name)
                == ["Mine"]
        )
        #expect(
            FileManager.default.fileExists(
                atPath: core.paletteLibrary.url.path
            )
        )
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

        // The verdict has its one consumer here: every doomed
        // file went.
        #expect(
            core.resetAllSettings(trash: {
                try FileManager.default.removeItem(at: $0)
            })
        )

        // The sidecar reseeded, the poisoned space and profile
        // gone, factory settings back, init.lua untouched.
        #expect(core.guiConfigStore.exists)
        let spaces = core.state.workspaces.allSpaces.map(\.id)
        #expect(!spaces.contains(SpaceID("poison")))
        #expect(!core.profiles.list().contains("Poisoned"))
        // First-launch state is the starter setup's tuning (the
        // Starter profile seed applies it), not bare
        // TilingSettings() — derive from the one source, and
        // from the same MAIN screen the seed derived it from,
        // since the tuning follows that screen's class (#678
        // Phase 4 pass 11).
        let seededShape = ScreenClass.of(
            StarterSetup.sizes(
                displays: core.state.workspaces.allDisplays,
                mainID: PositionalDisplays.liveMainID
            )[0]
        )
        #expect(
            core.tiler.settings.gapsGlobal
                == StarterTuning.settings(mainShape: seededShape)
                .gapsGlobal
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
        var mode = KeyLayer.defaultLayer
        mode.name = "poison-mode"
        config.layers.append(mode)
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
        let files = FileManager.default
        func luaCore() throws -> KiwiCore {
            let dir = files.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-reset-\(UUID().uuidString)"
                )
            try files.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            let core = makeTestCore(configDirectory: dir)
            core.onLog = { _ in }
            // A Lua-owned config: declares managed settings,
            // so no sidecar and no ladder ever seed for it —
            // and nothing re-stamps the live overlay after a
            // reset, which makes THIS the path where every
            // hand-clear in resetAllSettings is load-bearing
            // and observable.
            try "KiwiDesk.set_gap_global(5)\n".write(
                to: core.configURL,
                atomically: true,
                encoding: .utf8
            )
            core.loadConfig()
            return core
        }

        let virgin = try luaCore()
        defer {
            try? files.removeItem(at: virgin.configDirectory)
        }
        let core = try luaCore()
        defer {
            try? files.removeItem(at: core.configDirectory)
        }
        // Poison every live-overlay family the seed captures
        // and only the reset clears on this path: a space, an
        // undeclared settings field, a pin, a Main role.
        core.state.workspaces.ensureSpace(SpaceID("poison"))
        core.tiler.settings.animations.durationMS = 999
        core.spacePins[SpaceID(1)] = "A:1x1"
        core.mainSpaces.insert(SpaceID(1))

        core.resetAllSettings(trash: {
            try FileManager.default.removeItem(at: $0)
        })
        // The forget-proof net (review round 2): the seed is
        // the whole live overlay as a value — settings, pins,
        // Main roles, modes, fallback, every future stored
        // field — so a hand-clear the reset forgets shows up
        // as an inequality against the virgin twin, not as a
        // silently narrower hand-pin list.
        #expect(core.guiConfigSeed() == virgin.guiConfigSeed())
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
            ) == "KiwiDesk.set_gap_global(5)\n"
        )
    }
}
