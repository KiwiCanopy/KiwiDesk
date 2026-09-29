import Foundation
import Testing

@testable import KiwiDeskCore

/// The shared look's crossing and resolution (#1752): the first
/// apply of a stored profile seeds the shared look from it, every
/// profile already wearing it follows from then on, a profile that
/// differs keeps its own, and a follower runs the shared look.
/// Profiles are saved as the one-shot step leaves them, `own`.
@Suite("Shared look crossing (#1752)", .serialized)
@MainActor
struct SharedLookCrossingTests {
    private func makeGuiCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-shared-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        return core
    }

    private func profile(
        _ name: String,
        fill: String = TilingSettings().kiwishelf.fillColor,
        look: LookReference? = .own
    ) -> Profile {
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = fill
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

    @Test("the first apply seeds the shared look; twins follow it")
    func crossingSeedsAndTwinsFollow() throws {
        let core = try makeGuiCore()
        try core.profiles.save(profile("Work"))
        try core.profiles.save(profile("Twin"))
        try core.profiles.save(profile("Odd", fill: "#0A0B0C"))
        core.prepareSharedLook()
        load("Work", core)
        let work = try core.profiles.read(name: "Work")
        #expect(core.sharedLook == LookBody(of: work.settings))
        #expect(core.guiConfigStore.load()?.look == core.sharedLook)
        #expect(work.look == nil)
        #expect(try core.profiles.read(name: "Twin").look == nil)
        #expect(try core.profiles.read(name: "Odd").look == .own)
    }

    @Test("a follower runs the shared look over its own copy")
    func followerRunsTheSharedLook() throws {
        let core = try makeGuiCore()
        try core.profiles.save(profile("Work"))
        core.prepareSharedLook()
        load("Work", core)
        // A stale copy in the follower's file is never read.
        try core.profiles.save(profile("Stale", fill: "#0A0B0C", look: nil))
        load("Stale", core)
        #expect(
            core.tiler.settings.kiwishelf.fillColor
                == TilingSettings().kiwishelf.fillColor
        )
    }

    @Test("an own look runs its own copy")
    func ownRunsItsCopy() throws {
        let core = try makeGuiCore()
        try core.profiles.save(profile("Work"))
        try core.profiles.save(profile("Odd", fill: "#0A0B0C"))
        core.prepareSharedLook()
        load("Work", core)
        load("Odd", core)
        #expect(core.tiler.settings.kiwishelf.fillColor == "#0A0B0C")
    }

    @Test("a profile nobody stored lends nothing")
    func builtInLendsNothing() throws {
        let core = try makeGuiCore()
        core.prepareSharedLook()
        core.adoptSharedLook(from: profile("Ghost"))
        #expect(core.sharedLook == nil)
        #expect(core.guiConfigStore.load()?.look == nil)
    }

    @Test("an unreadable gui.json owes nothing and rewrites no profile")
    func unreadableOwesNothing() throws {
        let core = try makeGuiCore()
        try core.profiles.save(profile("Work"))
        try Data("{".utf8).write(to: core.guiConfigStore.url)
        core.prepareSharedLook()
        core.adoptSharedLook(from: try core.profiles.read(name: "Work"))
        #expect(core.sharedLook == nil)
        #expect(try core.profiles.read(name: "Work").look == .own)
    }

    /// gui.json first: a crossing whose write fails rewrites no
    /// profile and stays owed for the next apply.
    @Test("a failed gui.json write rewrites no profile")
    func failedWriteLeavesProfiles() throws {
        let core = try makeGuiCore()
        try core.profiles.save(profile("Work"))
        core.prepareSharedLook()
        try Data("{".utf8).write(to: core.guiConfigStore.url)
        core.adoptSharedLook(from: try core.profiles.read(name: "Work"))
        #expect(core.sharedLook == nil)
        #expect(core.sharedLookLedger.owed)
        #expect(try core.profiles.read(name: "Work").look == .own)
    }

    @Test("a Lua-owned config has no shared look")
    func luaOwnedCrossesNothing() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-shared-\(UUID().uuidString)")
        )
        try core.profiles.save(profile("Work"))
        core.prepareSharedLook()
        load("Work", core)
        #expect(core.sharedLook == nil)
        #expect(try core.profiles.read(name: "Work").look == .own)
    }
}
