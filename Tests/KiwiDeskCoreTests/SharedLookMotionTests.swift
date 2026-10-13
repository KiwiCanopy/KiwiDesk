import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Animations join the shared look (#2176): a shared look missing a
/// motion path owes an election, settled by the first apply or look
/// write of a stored profile that FOLLOWS it, which elects its own
/// animations; another follower whose animations differ keeps its
/// own look, and an own profile is never touched.
@Suite("Shared look motion (#2176)", .serialized)
@MainActor
struct SharedLookMotionTests {
    /// A core whose `gui.json` carries the pre-#2176 shared look:
    /// styling and colours, no motion.
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-motion-\(UUID().uuidString)")
        )
        let settings = TilingSettings()
        var config = GuiConfig()
        config.look = LookBody(
            style: LookKeys.extract(
                from: settings,
                paths: LookKeys.styling
            ),
            colors: ColorPaletteKeys.extract(from: settings)
        )
        try core.guiConfigStore.save(config)
        return core
    }

    private func profile(
        _ name: String,
        duration: Int,
        fill: String = TilingSettings().kiwishelf.fillColor,
        look: LookReference? = nil
    ) -> Profile {
        var settings = TilingSettings()
        settings.animations.durationMS = duration
        settings.kiwishelf.fillColor = fill
        return Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: settings,
            look: look
        )
    }

    private func stored(_ name: String, _ core: KiwiCore) throws -> Profile {
        try core.profiles.read(name: name)
    }

    private func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)])
                .isSuccess
        )
    }

    private func duration(_ name: String, _ core: KiwiCore) throws -> Int {
        try stored(name, core).settings.animations.durationMS
    }

    /// The boot shape: nothing adopted, so the load elects nothing
    /// and the first apply of a follower elects its animations.
    @Test("the first apply of a follower elects its animations")
    func followerApplyElects() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Calm", duration: 300))
        try core.profiles.save(profile("Fast", duration: 100))
        try core.profiles.save(profile("Odd", duration: 50, look: .own))
        core.profiles.resetAdoption()
        core.prepareSharedLook()
        #expect(core.sharedLookLedger.motionOwed)
        load("Fast", core)
        #expect(!core.sharedLookLedger.motionOwed)
        let shared = core.guiConfigStore.load()?.look
        #expect(shared?.style["animations.duration"] == .number(100))
        #expect(try stored("Fast", core).look == nil)
        // Another follower that differs keeps its own, and its speed.
        #expect(try stored("Calm", core).look == .own)
        #expect(try duration("Calm", core) == 300)
        #expect(try stored("Odd", core).look == .own)
        #expect(try duration("Odd", core) == 50)
    }

    @Test("an own profile elects nothing")
    func ownApplyElectsNothing() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Calm", duration: 300))
        try core.profiles.save(profile("Odd", duration: 50, look: .own))
        core.profiles.resetAdoption()
        core.prepareSharedLook()
        load("Odd", core)
        #expect(core.sharedLookLedger.motionOwed)
        #expect(try stored("Calm", core).look == nil)
    }

    /// The frozen copy wears the shared styling it ran, not the
    /// stale copy in its file.
    @Test("a follower that leaves keeps the look it ran")
    func leaverKeepsWhatItRan() throws {
        let core = try makeCore()
        try core.profiles.save(
            profile("Stale", duration: 100, fill: "#0A0B0C")
        )
        try core.profiles.save(profile("Work", duration: 300))
        core.profiles.resetAdoption()
        core.prepareSharedLook()
        load("Work", core)
        let stale = try stored("Stale", core)
        #expect(stale.look == .own)
        #expect(
            stale.settings.kiwishelf.fillColor
                == TilingSettings().kiwishelf.fillColor
        )
        #expect(stale.settings.animations.durationMS == 100)
    }

    /// The real write shape with the crossing still owed: the file
    /// is written, then the look write lands — its writer elects,
    /// stays following, and its styling reaches the followers left.
    @Test("a look write while owed elects its writer")
    func writeElectsItsWriter() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Calm", duration: 500))
        try core.profiles.save(profile("Fast", duration: 100))
        try core.profiles.save(profile("Work", duration: 300))
        core.profiles.resetAdoption()
        core.prepareSharedLook()
        var work = try stored("Work", core)
        work.settings.animations.durationMS = 500
        work.settings.kiwishelf.fillColor = "#102030"
        try core.profiles.write(work)
        core.commitSharedLook(ofProfile: "Work")
        #expect(!core.sharedLookLedger.motionOwed)
        #expect(try stored("Work", core).look == nil)
        let calm = try stored("Calm", core)
        #expect(calm.look == nil)
        #expect(calm.settings.kiwishelf.fillColor == "#102030")
        #expect(try stored("Fast", core).look == .own)
        #expect(try duration("Fast", core) == 100)
    }

    /// No `gui.json` write, no profile write: the crossing stays
    /// owed for the next apply.
    @Test("a failed write leaves it owed and every profile as it was")
    func failedWriteChangesNothing() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Calm", duration: 300))
        try core.profiles.save(profile("Fast", duration: 100))
        core.profiles.resetAdoption()
        core.prepareSharedLook()
        let config = core.guiConfigStore.url
        let directory = config.deletingLastPathComponent()
        let manager = FileManager.default
        try manager.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: directory.path
        )
        defer {
            try? manager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: directory.path
            )
        }
        core.settleSharedMotion(electing: try stored("Calm", core))
        #expect(core.sharedLookLedger.motionOwed)
        #expect(try stored("Fast", core).look == nil)
    }

    /// A Standard saved through `applyStandard` is born a follower,
    /// so its preset animations are the ones elected.
    @Test("a saved Standard elects its animations")
    func savedStandardElects() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Fast", duration: 100))
        core.profiles.resetAdoption()
        core.prepareSharedLook()
        core.state.apply(
            .displaysChanged([
                Display(
                    id: DisplayID(10),
                    name: "D",
                    frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
                )
            ])
        )
        let preset = try #require(
            StandardProfiles.workflows.first { $0.screenCount == 1 }
        )
        try core.applyStandard(preset)
        #expect(!core.sharedLookLedger.motionOwed)
        #expect(try stored("Fast", core).look == .own)
        #expect(try duration("Fast", core) == 100)
    }

    /// The tour's paint is a look write through the live-profile
    /// door: adopted but never applied, its writer elects.
    @Test("a paint through the live-profile door elects its writer")
    func livePaintElectsItsWriter() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Fast", duration: 100))
        try core.profiles.save(profile("Work", duration: 300))
        core.prepareSharedLook()
        #expect(core.sharedLookLedger.motionOwed)
        let pick = LookBody(of: TilingSettings()).named("Pick")
        core.paintShelf(look: pick, palette: nil)
        #expect(!core.sharedLookLedger.motionOwed)
        #expect(try stored("Work", core).look == nil)
        #expect(try stored("Fast", core).look == .own)
        #expect(try duration("Fast", core) == 100)
    }

    @Test("a shared look that carries motion owes no election")
    func carriedMotionOwesNothing() throws {
        let core = try makeCore()
        var config = try #require(core.guiConfigStore.load())
        config.look = LookBody(of: TilingSettings())
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Fast", duration: 100))
        core.prepareSharedLook()
        #expect(!core.sharedLookLedger.motionOwed)
        #expect(try stored("Fast", core).look == nil)
    }
}
