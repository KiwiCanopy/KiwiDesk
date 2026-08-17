import Foundation
import Testing

@testable import KiwiDeskCore

/// Who may restore what: the config-ownership refusal, and the
/// failure paths a restore can still hit after it has started
/// (#606).
///
/// Split from `SetupRestoreTests` at §2.1's ceiling. The seam is
/// real rather than arbitrary: that suite asks what a restore
/// LANDS, this asks when it is refused and what it costs when it
/// cannot finish.
@Suite("Setup restore: ownership and failure (#606)")
@MainActor
struct SetupRestoreOwnershipTests {
    private let hardDelete: (URL) throws -> Void = {
        try FileManager.default.removeItem(at: $0)
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

    private func palette(_ name: String) -> ColorPalette {
        ColorPalette(
            name: name,
            colors: [ColorPaletteKeys.all[0]: "#112233"]
        )
    }

    private func incomingBundle() -> SetupBundle {
        var config = GuiConfig()
        config.spaces = [SpaceID("work"), SpaceID("play")]
        return SetupBundle(
            writtenBy: "0.9.6",
            config: config,
            profiles: [
                profile("Imported", spaces: [SpaceID("work")])
            ],
            palettes: [palette("Imported")]
        )
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

    @Test("A Lua-owned Mac refuses a settings backup untouched")
    func luaOwnedDestinationRefuses() throws {
        let core = makeTestCore()
        try makeLuaOwned(core)
        try core.profiles.save(profile("Local"))
        #expect(!core.isGuiManaged)

        #expect(throws: SetupBundleError.luaOwnsThisMac) {
            try core.restoreSetup(
                from: incomingBundle(),
                trash: hardDelete
            )
        }
        // **Untouched** is the half that matters: the refusal
        // comes before anything is trashed, so a user who cannot
        // take the restore still has their setup.
        #expect(
            core.profiles.allProfiles().map(\.name) == ["Local"]
        )
    }

    @Test("A profile-only backup still restores onto a Lua Mac")
    func luaOwnedTakesAProfileOnlyBackup() throws {
        let core = makeTestCore()
        try makeLuaOwned(core)

        // No settings to fight over, so nothing is half-landed —
        // the refusal is scoped to what actually cannot apply.
        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "0.9.6",
                config: nil,
                profiles: [profile("Imported")],
                palettes: []
            ),
            trash: hardDelete
        )
        #expect(
            core.profiles.allProfiles().map(\.name) == ["Imported"]
        )
    }
}
