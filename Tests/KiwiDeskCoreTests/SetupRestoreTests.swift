import Foundation
import Testing

@testable import KiwiDeskCore

/// Restoring a backup over a live install (#606).
///
/// Every test injects a hard delete for `trash`, exactly as
/// `ResetEscapeHatchTests` does — the production policy is
/// Move-to-Trash and a test that took it would fill the
/// developer's Trash, which is why the parameter carries no
/// default on either call.
@Suite("Setup restore replaces what it says (#606)")
@MainActor
struct SetupRestoreTests {
    private let hardDelete: (URL) throws -> Void = {
        try FileManager.default.removeItem(at: $0)
    }

    /// Make this core Lua-owned: an `init.lua` declaring managed
    /// settings, and no sidecar. The directory has to exist first
    /// — `makeTestCore` names a scratch path, it does not create
    /// it.
    private func makeLuaOwned(_ core: KiwiCore) throws {
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "KiwiDesk.set_gap(8)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private func palette(
        _ name: String,
        hex: String = "#112233"
    ) -> ColorPalette {
        ColorPalette(
            name: name,
            colors: [ColorPaletteKeys.all[0]: hex]
        )
    }

    private func profile(
        _ name: String,
        spaces: [SpaceID] = [SpaceID("1")]
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: spaces,
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    /// A backup describing a setup that shares nothing with the
    /// install it will land on.
    private func incomingBundle() -> SetupBundle {
        var config = GuiConfig()
        config.spaces = [SpaceID("work"), SpaceID("play")]
        return SetupBundle(
            writtenBy: "0.9.6",
            config: config,
            profiles: [profile("Imported", spaces: [SpaceID("work")])],
            palettes: [palette("Imported")]
        )
    }

    @Test("The incoming config, profiles and palettes all land")
    func everythingLands() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())

        try core.restoreSetup(from: incomingBundle(), trash: hardDelete)

        #expect(
            core.guiConfigStore.load()?.spaces
                == [SpaceID("work"), SpaceID("play")]
        )
        #expect(
            core.profiles.allProfiles().map(\.name) == ["Imported"]
        )
        #expect(
            core.paletteLibrary.userPalettes().map(\.name)
                == ["Imported"]
        )
    }

    @Test("Replace, not merge: what was there is gone")
    func theOldSetupIsReplaced() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Local"))
        try core.paletteLibrary.save(palette("Local"))

        try core.restoreSetup(from: incomingBundle(), trash: hardDelete)

        // Merging would have kept these and made the result depend
        // on what happened to be on the destination Mac. The
        // confirm the user answered says replace.
        #expect(
            !core.profiles.allProfiles().map(\.name)
                .contains("Local")
        )
        #expect(
            !core.paletteLibrary.userPalettes().map(\.name)
                .contains("Local")
        )
    }

    @Test("Live spaces the backup never mentions do not survive")
    func staleLiveSpacesArePruned() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        core.state.workspaces.ensureSpace(SpaceID("leftover"))

        try core.restoreSetup(from: incomingBundle(), trash: hardDelete)

        // The trap `KiwiCore+Reset` documents, one door over:
        // `loadConfig` SEEDS the sidecar's spaces but never removes
        // a live one the sidecar stopped mentioning, so without an
        // explicit prune the destination Mac keeps both setups at
        // once.
        let live = Set(core.state.workspaces.allSpaces.map(\.id))
        #expect(!live.contains(SpaceID("leftover")))
        #expect(live.contains(SpaceID("work")))
    }

    @Test("A backup with no config leaves the live spaces alone")
    func noConfigMeansNoPrune() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        core.state.workspaces.ensureSpace(SpaceID("keep"))
        let bundle = SetupBundle(
            writtenBy: "0.9.6",
            config: nil,
            profiles: [profile("Imported")],
            palettes: []
        )

        try core.restoreSetup(from: bundle, trash: hardDelete)

        // Nothing declared the space list, so nothing may prune it
        // — a Lua-owned backup must not silently delete the spaces
        // its own config never described.
        #expect(
            core.state.workspaces.allSpaces.map(\.id)
                .contains(SpaceID("keep"))
        )
    }

    @Test("A settings-only backup keeps the profiles it cannot replace")
    func settingsOnlyBackupKeepsProfiles() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Local"))
        var config = GuiConfig()
        config.spaces = [SpaceID("work")]

        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "0.9.6",
                config: config,
                profiles: [],
                palettes: []
            ),
            trash: hardDelete
        )

        // The discard used to be unconditional for profiles, so a
        // settings-only bundle trashed every profile and wrote none
        // back. `ConfigArtifact.isCarried` is the one rule now.
        #expect(
            core.profiles.allProfiles().map(\.name) == ["Local"]
        )
    }

    @Test("A palette shadowing a built-in is dropped, not restored")
    func shadowingPaletteIsDropped() throws {
        let core = makeTestCore()
        // A sidecar, so this core is GUI-managed: without one the
        // restore now refuses as `.luaOwnsThisMac` and this test
        // would be asserting about a refusal instead of a filter.
        try core.guiConfigStore.save(GuiConfig())
        let builtin = try #require(
            core.paletteLibrary.builtins().first?.name
        )
        let bundle = SetupBundle(
            writtenBy: "0.9.6",
            config: GuiConfig(),
            profiles: [],
            palettes: [palette(builtin), palette("Fine")]
        )

        try core.restoreSetup(from: bundle, trash: hardDelete)

        // The bundle is JSON on the user's disk, so a hand-edited
        // one can carry a name `save` would refuse one at a time.
        // The shadow would be invisible until the built-in stopped
        // resolving.
        let names = core.paletteLibrary.userPalettes().map(\.name)
        #expect(names == ["Fine"])
    }

    /// The restore reaches the RUNNING app, not only the disk.
    ///
    /// A `guard-prover` round deleted `loadConfig()` and the three
    /// calls after it and left all 18 tests green (2026-08-17):
    /// both suites read files and `state.workspaces`, and the
    /// workspaces half is mutated by the prune block *above* the
    /// reload — so the invariant that a restore lands on the live
    /// app had no net at all. That is the defect a user meets
    /// immediately: files replaced, app unchanged until relaunch.
    ///
    /// The gap probes the **apply**, and only the apply: deleting
    /// `applyProfileScopedState` reds this, while deleting
    /// `loadConfig()` leaves the suite green, the gap arriving off
    /// the in-memory bundle rather than off disk. So the reload's
    /// own work — the sidecar's rules and keybindings, and running
    /// `init.lua` — is watched by nothing here. Stated as a gap
    /// rather than implied covered.
    @Test("The restore lands on the running app, not just on disk")
    func theRestoreIsApplied() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        #expect(core.tiler.settings.gapsGlobal.outer.top == 10)

        var config = GuiConfig()
        config.spaces = [SpaceID("work")]
        config.settings.gapsGlobal.outer.top = 42
        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "0.9.6",
                config: config,
                profiles: [],
                palettes: []
            ),
            trash: hardDelete
        )

        #expect(core.tiler.settings.gapsGlobal.outer.top == 42)
    }

    @Test("Space modes and pins come back, not just the space list")
    func perSpaceStateIsApplied() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())

        var config = GuiConfig()
        config.spaces = [SpaceID("work"), SpaceID("play")]
        config.spaceModes = [
            SpaceID("work"): .monocle, SpaceID("play"): .grid,
        ]
        config.mainSpaces = [SpaceID("work")]
        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "0.9.6",
                config: config,
                profiles: [],
                palettes: []
            ),
            trash: hardDelete
        )

        // The hand-rolled prune this replaced set none of these:
        // it ensured the spaces and stopped, so a restored setup
        // came back with every space on the default layout and no
        // Main role — right list, wrong everything else.
        #expect(
            core.state.workspaces[SpaceID("work")]?.mode == .monocle
        )
        #expect(
            core.state.workspaces[SpaceID("play")]?.mode == .grid
        )
        #expect(core.mainSpaces == [SpaceID("work")])
    }

    @Test("A space named only by its mode is kept, not pruned")
    func spacesReachableOnlyByModeSurvive() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())

        var config = GuiConfig()
        // Deliberately NOT in `spaces` — only `spaceModes` names
        // it. The replaced prune took `config.spaces` as the whole
        // survivor set, so this space was written to disk and then
        // immediately pruned out of live: present in the backup,
        // absent from the running app.
        config.spaces = [SpaceID("work")]
        config.spaceModes = [SpaceID("solo"): .floating]
        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "0.9.6",
                config: config,
                profiles: [],
                palettes: []
            ),
            trash: hardDelete
        )

        let live = Set(core.state.workspaces.allSpaces.map(\.id))
        #expect(live.contains(SpaceID("solo")))
        #expect(live.contains(SpaceID("work")))
    }

    @Test("A restore that lands throws nothing")
    func aCleanRestoreThrowsNothing() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Local"))

        // The success arm of the throwing signature. A write that
        // fails AFTER the originals are in the Trash is the one
        // failure the pre-flight read cannot catch, so the happy
        // path has to be distinguishable from it.
        try core.restoreSetup(
            from: incomingBundle(),
            trash: hardDelete
        )
    }

    @Test("A trash that always fails still lands the restore")
    func fallsBackToDeleting() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Local"))
        struct Nope: Error {}

        try core.restoreSetup(from: incomingBundle()) { _ in
            throw Nope()
        }

        // A surviving gui.json would flip the reload back onto the
        // OLD sidecar and turn a confirmed replace into a silent
        // no-op — strictly worse than skipping the Trash courtesy.
        #expect(
            core.guiConfigStore.load()?.spaces
                == [SpaceID("work"), SpaceID("play")]
        )
        #expect(
            core.profiles.allProfiles().map(\.name) == ["Imported"]
        )
    }
}
