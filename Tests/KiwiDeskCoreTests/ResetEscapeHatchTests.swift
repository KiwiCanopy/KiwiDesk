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

        core.discardSavedArrangement()
        #expect(!files.fileExists(atPath: marker.path))
        #expect(!files.fileExists(atPath: session.path))
    }

    @Test("Reset reseeds first-launch state and keeps init.lua")
    func resetAllSettings() throws {
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
}
