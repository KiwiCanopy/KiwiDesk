import Foundation
import Testing

@testable import KiwiDeskCore

/// Animations join the shared look (#2176): a shared look adopted
/// before they joined carries none, so the next apply of a stored
/// profile elects its animations, and a follower whose animations
/// differ keeps its own look — nothing on screen moves.
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
        look: LookReference? = nil
    ) -> Profile {
        var settings = TilingSettings()
        settings.animations.durationMS = duration
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

    private func duration(_ name: String, _ core: KiwiCore) throws -> Int {
        try core.profiles.read(name: name).settings.animations.durationMS
    }

    @Test("the next apply elects its animations into the shared look")
    func applyElectsMotion() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Work", duration: 300))
        try core.profiles.save(profile("Calm", duration: 300))
        try core.profiles.save(profile("Fast", duration: 100))
        core.prepareSharedLook()
        #expect(core.sharedLookLedger.motionOwed)
        load("Work", core)
        #expect(!core.sharedLookLedger.motionOwed)
        let stored = core.guiConfigStore.load()?.look
        #expect(stored?.style["animations.duration"] == .number(300))
        #expect(try core.profiles.read(name: "Calm").look == nil)
        // A follower that differs keeps its own, and its speed.
        #expect(try core.profiles.read(name: "Fast").look == .own)
        #expect(try duration("Fast", core) == 100)
        load("Fast", core)
        #expect(core.tiler.settings.animations.durationMS == 100)
    }

    @Test("after the election a follower wears the shared motion")
    func followerWearsSharedMotion() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Work", duration: 300))
        try core.profiles.save(profile("Calm", duration: 300))
        core.prepareSharedLook()
        load("Work", core)
        var work = try core.profiles.read(name: "Work")
        work.settings.animations.durationMS = 500
        core.recordLookWrite(of: work)
        #expect(try duration("Calm", core) == 500)
    }

    /// A look write ahead of any apply elects first, so its
    /// animations never re-stamp a follower that ran its own.
    @Test("a write before the election elects first")
    func writeBeforeElectionElects() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Work", duration: 500))
        try core.profiles.save(profile("Fast", duration: 100))
        core.prepareSharedLook()
        core.recordLookWrite(of: try core.profiles.read(name: "Work"))
        #expect(!core.sharedLookLedger.motionOwed)
        #expect(try core.profiles.read(name: "Fast").look == .own)
        #expect(try duration("Fast", core) == 100)
    }

    @Test("a shared look that carries motion owes no election")
    func carriedMotionOwesNothing() throws {
        let core = try makeCore()
        var config = try #require(core.guiConfigStore.load())
        config.look = LookBody(of: TilingSettings())
        try core.guiConfigStore.save(config)
        core.prepareSharedLook()
        #expect(!core.sharedLookLedger.motionOwed)
    }
}
