import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class PausedRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// While Accessibility is off, `gui.json` globals stay saveable
/// (#516). The #335 gate exists to stop a *profile* recording a
/// degenerate 0-screen monitor set; none of the six global
/// fields has a monitor dependency, so it should never have
/// reached them — it did only because `saveGuiConfig` had one
/// caller and that caller sat behind the gate.
@Suite("Saving globals while paused", .serialized)
@MainActor
struct PausedGlobalsSaveTests {
    private func makeModel() throws -> (SettingsModel, KiwiCore) {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-paused-save-\(UUID().uuidString)"
                ),
            hotkeyRegistrar: PausedRegistrar()
        )
        try core.saveGuiConfig(GuiConfig())
        return (SettingsModel(core: core), core)
    }

    /// A global edit: an app rule, which has no monitor
    /// dependency whatsoever.
    private func editGlobal(_ model: SettingsModel) {
        model.config.appRules["com.example.app"] = SpaceID("2")
    }

    /// A tiling edit, which a globals-only save must NOT claim.
    private func editTiling(_ model: SettingsModel) {
        model.config.settings.gapsGlobal.inner.horizontal += 7
    }

    @Test("a pending global routes Save away from the gate")
    func pausedGlobalEditOffersSave() throws {
        let (model, _) = try makeModel()
        model.permissionPaused = true
        editGlobal(model)
        #expect(model.globalsChanged)
        #expect(model.primarySaveAction == .saveGlobalsOnly)
    }

    /// With nothing global pending there is nothing this path
    /// could write, so the #335 gate correctly stays in force
    /// and its monitor tooltip is finally accurate.
    @Test("no global change leaves the profile gate in force")
    func pausedWithoutGlobalEditKeepsGate() throws {
        let (model, _) = try makeModel()
        model.permissionPaused = true
        editTiling(model)
        #expect(!model.globalsChanged)
        #expect(model.primarySaveAction != .saveGlobalsOnly)
        #expect(model.profileSaveBlockedReason != nil)
    }

    /// The raw-Lua and stored-profile verbs write no monitor set
    /// either, so they were never blocked and must not be
    /// rerouted.
    @Test("the two unblocked verbs are not rerouted")
    func unblockedVerbsKeepTheirAction() throws {
        let (model, _) = try makeModel()
        model.permissionPaused = true
        editGlobal(model)
        model.showLuaEditor = true
        #expect(model.primarySaveAction == .saveLua)
        model.showLuaEditor = false
        model.target = .storedProfile("whatever")
        #expect(model.primarySaveAction == .updateStoredProfile)
    }

    @Test("the save reaches disk while paused")
    func globalsReachDisk() throws {
        let (model, core) = try makeModel()
        model.permissionPaused = true
        editGlobal(model)
        model.saveGlobalsWhilePaused()
        #expect(
            core.loadGuiConfig().appRules["com.example.app"]
                == SpaceID("2")
        )
    }

    /// The partial-clean contract: a globals-only save clears
    /// the global half and NOTHING else. A blanket `reload()`
    /// here would throw away staged tiling edits this save never
    /// persisted — the trap that makes this its own method
    /// rather than a flag on `persist(named:)`.
    @Test("tiling edits survive and keep the footer dirty")
    func tilingStaysDirtyAfterGlobalsSave() throws {
        let (model, _) = try makeModel()
        model.permissionPaused = true
        editGlobal(model)
        editTiling(model)
        let staged = model.config.settings.gapsGlobal.inner
            .horizontal

        model.saveGlobalsWhilePaused()

        #expect(!model.globalsChanged)
        #expect(
            model.config.settings.gapsGlobal.inner.horizontal
                == staged
        )
        #expect(model.isDirty)
    }

    /// With only globals pending, the same save clears the
    /// footer outright.
    @Test("a globals-only edit ends clean")
    func globalsOnlyEditEndsClean() throws {
        let (model, _) = try makeModel()
        model.permissionPaused = true
        editGlobal(model)
        model.saveGlobalsWhilePaused()
        #expect(!model.isDirty)
    }

    /// The data-loss regression, caught in review before it
    /// shipped. `loadGuiConfig` overlays `spaces` from LIVE
    /// state; paused means the engine never started, so live
    /// holds only the boot default and the overlay would replace
    /// the authored list with ["1"]. Before #516 nothing could
    /// write gui.json while paused, so that only mis-displayed —
    /// a globals save would have PERSISTED it and destroyed the
    /// user's spaces on a fresh install or after a rebuild drops
    /// the TCC grant.
    ///
    /// Built deliberately without letting `loadConfig()` run:
    /// going through `core.saveGuiConfig` would start the engine
    /// and hide the very state under test.
    @Test("a paused save never overwrites the authored spaces")
    func pausedSaveKeepsAuthoredSpaces() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-paused-spaces-\(UUID().uuidString)"
            )
        var authored = GuiConfig()
        authored.spaces = [SpaceID("work"), SpaceID("mail")]
        try GuiConfigStore(directory: directory).save(authored)

        let core = KiwiCore(
            configDirectory: directory,
            hotkeyRegistrar: PausedRegistrar()
        )
        let model = SettingsModel(core: core)
        model.permissionPaused = true
        // Re-seed now that the flag is set — the dashboard is
        // opened after the app knows it is paused.
        model.reload()

        #expect(
            model.config.spaces == [
                SpaceID("work"), SpaceID("mail"),
            ]
        )

        editGlobal(model)
        model.saveGlobalsWhilePaused()

        let onDisk = try #require(
            GuiConfigStore(directory: directory).load()
        )
        #expect(
            onDisk.spaces.contains(SpaceID("work")),
            "the paused save destroyed the authored space list"
        )
        #expect(onDisk.spaces.contains(SpaceID("mail")))
    }

    /// A Lua-owned config has no sidecar baseline, and
    /// `globalsChanged` reports true for an unknown baseline —
    /// so without the `savedSidecar != nil` guard this offered
    /// the globals Save with nothing pending, and writing it
    /// would create gui.json and seize ownership from init.lua
    /// outside the sanctioned adopt path.
    @Test("a Lua-owned config is not offered the globals save")
    func luaOwnedConfigKeepsItsOwnAction() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-paused-lua-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try "print('hello')".write(
            to: directory.appendingPathComponent("init.lua"),
            atomically: true,
            encoding: .utf8
        )
        let core = KiwiCore(
            configDirectory: directory,
            hotkeyRegistrar: PausedRegistrar()
        )
        let model = SettingsModel(core: core)
        model.permissionPaused = true
        model.reload()

        #expect(!core.isGuiManaged)
        #expect(model.savedSidecar == nil)
        #expect(model.primarySaveAction != .saveGlobalsOnly)
    }

    /// `spaces` is one of the six, and its freshness net has to
    /// run on this path too: a space that appeared live while
    /// the dashboard sat open must not be pruned by the save.
    @Test("the space freshness net still runs")
    func liveSpacesAreMerged() throws {
        let (model, core) = try makeModel()
        model.permissionPaused = true
        _ = core.execute(
            "create_space",
            args: [.string("scratch")]
        )
        editGlobal(model)
        model.saveGlobalsWhilePaused()
        #expect(
            core.loadGuiConfig().spaces.contains(
                SpaceID("scratch")
            )
        )
    }
}
