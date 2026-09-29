import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Where a change to the shared look lands (#1752): a follower's
/// file copy is re-stamped and the live screen re-resolved, a
/// restore takes the bundle's shared look or owes the crossing
/// again, a profile born with no shared look keeps its own, and the
/// crossing's election moves such a profile to own where it wears
/// another look.
@Suite("Shared look landing (#1752)", .serialized)
@MainActor
struct SharedLookLandTests {
    private let odd = "#0A0B0C"

    private func guiCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-land-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        return core
    }

    /// Work and Twin follow the shared look, seeded from Work.
    private func crossedCore() throws -> KiwiCore {
        let core = try guiCore()
        try core.profiles.save(profile("Work"))
        try core.profiles.save(profile("Twin"))
        core.prepareSharedLook()
        load("Work", core)
        return core
    }

    private func profile(
        _ name: String,
        fill: String? = nil,
        look: LookReference? = .own
    ) -> Profile {
        var settings = TilingSettings()
        if let fill { settings.kiwishelf.fillColor = fill }
        return Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: settings,
            look: look
        )
    }

    private func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)])
                .isSuccess
        )
    }

    private func fill(_ name: String, _ core: KiwiCore) throws -> String {
        try core.profiles.read(name: name).settings.kiwishelf.fillColor
    }

    @Test("a follower's file copy is re-stamped")
    func followersAreRestamped() throws {
        let core = try crossedCore()
        core.tiler.settings.kiwishelf.fillColor = odd
        try core.persistProfile(named: "Work", modes: nil)
        #expect(try fill("Twin", core) == odd)
    }

    @Test("a stored follower's Save re-resolves the live screen")
    func liveScreenReresolves() throws {
        let core = try crossedCore()
        var edited = try core.loadGuiConfig(editing: "Twin")
        edited.settings.kiwishelf.fillColor = odd
        try core.overwriteProfile(
            named: "Twin",
            with: edited,
            writingRules: true
        )
        core.commitSharedLook(ofProfile: "Twin")
        #expect(core.profiles.currentName == "Work")
        #expect(core.tiler.settings.kiwishelf.fillColor == odd)
    }

    @Test("a restore takes the bundle's shared look")
    func restoreTakesTheBundle() throws {
        let core = try crossedCore()
        var shared = TilingSettings()
        shared.kiwishelf.fillColor = odd
        var config = GuiConfig()
        config.look = LookBody(of: shared)
        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "test",
                config: config,
                profiles: [],
                palettes: []
            )
        ) { _ in }
        #expect(core.sharedLook?.colors["kiwishelf.fill_color"] == odd)
        #expect(core.guiConfigStore.load()?.look == config.look)
    }

    /// A pre-#1752 backup carries no shared look, so its restore
    /// elects again — from the RESTORED profile, never this Mac's
    /// earlier shared look, which the restore's write would
    /// otherwise have stamped over it.
    @Test("a backup from before the move elects from its own profile")
    func legacyRestoreElectsAgain() throws {
        let core = try crossedCore()
        try core.restoreSetup(
            from: SetupBundle(
                writtenBy: "test",
                config: GuiConfig(),
                profiles: [profile("Work", fill: odd)],
                palettes: []
            )
        ) { _ in }
        #expect(core.sharedLook?.colors["kiwishelf.fill_color"] == odd)
        #expect(try core.profiles.read(name: "Work").look == nil)
    }

    @Test("a profile born with no shared look keeps its own")
    func bornOwnWithoutShared() throws {
        let core = try guiCore()
        try core.persistProfile(named: "New", modes: nil)
        #expect(try core.profiles.read(name: "New").look == .own)
    }

    @Test("the election moves a follower wearing another look to own")
    func electionMovesStrayFollowers() throws {
        let core = try guiCore()
        try core.profiles.save(profile("Work"))
        try core.profiles.save(profile("Stray", fill: odd, look: nil))
        core.prepareSharedLook()
        load("Work", core)
        #expect(try core.profiles.read(name: "Stray").look == .own)
        #expect(try fill("Stray", core) == odd)
    }
}
