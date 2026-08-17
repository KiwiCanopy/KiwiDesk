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

        core.restoreSetup(from: incomingBundle(), trash: hardDelete)

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

        core.restoreSetup(from: incomingBundle(), trash: hardDelete)

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

        core.restoreSetup(from: incomingBundle(), trash: hardDelete)

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

        core.restoreSetup(from: bundle, trash: hardDelete)

        // Nothing declared the space list, so nothing may prune it
        // — a Lua-owned backup must not silently delete the spaces
        // its own config never described.
        #expect(
            core.state.workspaces.allSpaces.map(\.id)
                .contains(SpaceID("keep"))
        )
    }

    @Test("A palette shadowing a built-in is dropped, not restored")
    func shadowingPaletteIsDropped() throws {
        let core = makeTestCore()
        let builtin = try #require(
            core.paletteLibrary.builtins().first?.name
        )
        let bundle = SetupBundle(
            writtenBy: "0.9.6",
            config: GuiConfig(),
            profiles: [],
            palettes: [palette(builtin), palette("Fine")]
        )

        core.restoreSetup(from: bundle, trash: hardDelete)

        // The bundle is JSON on the user's disk, so a hand-edited
        // one can carry a name `save` would refuse one at a time.
        // The shadow would be invisible until the built-in stopped
        // resolving.
        let names = core.paletteLibrary.userPalettes().map(\.name)
        #expect(names == ["Fine"])
    }

    @Test("Restore reports success when every file was removed")
    func reportsWhetherItCleared() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Local"))

        #expect(
            core.restoreSetup(
                from: incomingBundle(),
                trash: hardDelete
            )
        )
    }

    @Test("A trash that always fails still lands the restore")
    func fallsBackToDeleting() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Local"))
        struct Nope: Error {}

        core.restoreSetup(from: incomingBundle()) { _ in
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
