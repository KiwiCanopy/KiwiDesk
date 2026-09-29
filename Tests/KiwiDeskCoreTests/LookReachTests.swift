import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The "Look applies to" checklist's writes (#1752): going own
/// freezes the look worn now, going shared keeps the copy unread,
/// a profile no change reached is not rewritten, and the live
/// profile the checklist reached is re-applied.
@Suite("Look reach (#1752)", .serialized)
@MainActor
struct LookReachTests {
    private let odd = "#0A0B0C"

    private func crossedCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-reach-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Work"))
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

    @Test("the reach reads every profile's switch")
    func reachReadsTheSwitches() throws {
        let core = try crossedCore()
        try core.profiles.save(profile("Odd", fill: odd))
        #expect(core.lookReach() == ["Work": true, "Odd": false])
    }

    @Test("going own freezes the shared look into the file")
    func ownFreezesTheSharedLook() throws {
        let core = try crossedCore()
        try core.profiles.save(profile("Stale", fill: odd, look: nil))
        try core.saveLookReach(["Stale": false])
        let stale = try core.profiles.read(name: "Stale")
        #expect(stale.look == .own)
        #expect(stale.settings.kiwishelf.fillColor != odd)
        #expect(core.sharedLook?.isWorn(by: stale.settings) == true)
    }

    /// The copy is re-stamped to the shared look it now wears
    /// (`landSharedLook`'s rule), so an older build or a Lua-owned
    /// load reads what it shows.
    @Test("going shared re-stamps the copy")
    func sharedKeepsTheCopy() throws {
        let core = try crossedCore()
        try core.profiles.save(profile("Odd", fill: odd))
        try core.saveLookReach(["Odd": true])
        let odd = try core.profiles.read(name: "Odd")
        #expect(odd.look == nil)
        #expect(odd.settings.kiwishelf.fillColor != self.odd)
        load("Odd", core)
        #expect(core.tiler.settings.kiwishelf.fillColor != self.odd)
    }

    @Test("a profile no change reached is not rewritten")
    func unreachedIsNotRewritten() throws {
        let core = try crossedCore()
        let url = try core.profiles.fileURL(name: "Work")
        // Non-canonical bytes that still decode: any rewrite, even
        // one that encodes the same profile, changes them.
        let before = try Data(contentsOf: url) + Data("\n\n".utf8)
        try before.write(to: url)
        try core.saveLookReach(["Work": true])
        #expect(try Data(contentsOf: url) == before)
    }

    @Test("the live profile the checklist reached is re-applied")
    func liveReachReapplies() throws {
        let core = try crossedCore()
        try core.profiles.save(profile("Odd", fill: odd))
        load("Odd", core)
        #expect(core.tiler.settings.kiwishelf.fillColor == odd)
        try core.saveLookReach(["Odd": true])
        #expect(core.tiler.settings.kiwishelf.fillColor != odd)
        #expect(core.profiles.currentName == "Odd")
    }

    @Test("with no shared look yet, opting in seeds it")
    func optInSeeds() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-reach-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Odd", fill: odd))
        try core.saveLookReach(["Odd": true])
        #expect(core.sharedLook?.colors["kiwishelf.fill_color"] == odd)
        #expect(core.guiConfigStore.load()?.look == core.sharedLook)
    }
}
