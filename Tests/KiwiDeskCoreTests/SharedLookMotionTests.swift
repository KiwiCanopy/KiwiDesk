import Foundation
import Testing

@testable import KiwiDeskCore

/// Animations join the shared look (#2176): a shared look adopted
/// before they joined lacks them, so the config load elects them
/// from a profile that FOLLOWS it, and a follower whose animations
/// differ keeps its own look — nothing on screen moves, and an own
/// profile is never touched.
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

    /// Saved last, the own profile is the live one, so the election
    /// falls to the first follower by name — never the own one.
    @Test("the load elects a follower's animations")
    func loadElectsFromAFollower() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Calm", duration: 300))
        try core.profiles.save(profile("Fast", duration: 100))
        try core.profiles.save(profile("Odd", duration: 50, look: .own))
        core.prepareSharedLook()
        #expect(!core.sharedLookLedger.motionOwed)
        let shared = core.guiConfigStore.load()?.look
        #expect(shared?.style["animations.duration"] == .number(300))
        #expect(try stored("Calm", core).look == nil)
        // A follower that differs keeps its own look, and its speed.
        #expect(try stored("Fast", core).look == .own)
        #expect(
            try stored("Fast", core).settings.animations.durationMS == 100
        )
        // An own profile is never touched.
        #expect(try stored("Odd", core).look == .own)
    }

    @Test("the live follower is the one elected")
    func liveFollowerIsElected() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Calm", duration: 300))
        try core.profiles.save(profile("Work", duration: 500))
        core.prepareSharedLook()
        let shared = core.guiConfigStore.load()?.look
        #expect(shared?.style["animations.duration"] == .number(500))
        #expect(try stored("Calm", core).look == .own)
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
        core.prepareSharedLook()
        let stale = try stored("Stale", core)
        #expect(stale.look == .own)
        #expect(
            stale.settings.kiwishelf.fillColor
                == TilingSettings().kiwishelf.fillColor
        )
        #expect(stale.settings.animations.durationMS == 100)
    }

    /// The real write shape: the file is written, then the look
    /// write lands — a styling and motion edit keeps its writer
    /// following and reaches the other followers.
    @Test("a look write after the election keeps its writer")
    func writeKeepsItsWriter() throws {
        let core = try makeCore()
        try core.profiles.save(profile("Calm", duration: 300))
        try core.profiles.save(profile("Work", duration: 300))
        core.prepareSharedLook()
        var work = try stored("Work", core)
        work.settings.animations.durationMS = 500
        work.settings.kiwishelf.fillColor = "#102030"
        try core.profiles.write(work)
        core.commitSharedLook(ofProfile: "Work")
        #expect(try stored("Work", core).look == nil)
        let calm = try stored("Calm", core)
        #expect(calm.look == nil)
        #expect(calm.settings.animations.durationMS == 500)
        #expect(calm.settings.kiwishelf.fillColor == "#102030")
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
