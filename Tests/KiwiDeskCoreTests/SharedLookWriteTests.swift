import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Where a look write lands (#1752): a follower's look is the
/// shared one, so a Keep, a Save as and a stored-profile Save write
/// it there; an own profile's write stays its own; a new profile
/// copies the live profile's switch; a copy touches no global file;
/// a built-in and a stored-profile draft wear what applies.
@Suite("Shared look writes (#1752)", .serialized)
@MainActor
struct SharedLookWriteTests {
    private let odd = "#0A0B0C"

    /// A GUI-managed core whose crossing seeded the shared look
    /// from "Work", which follows it.
    private func crossedCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-shared-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        connect(core)
        try core.profiles.save(profile("Work"))
        core.prepareSharedLook()
        load("Work", core)
        #expect(core.sharedLook != nil)
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

    /// One 100x100 screen, the fixture profiles' "A:100x100" set,
    /// so a Keep's screen-count check passes.
    private func connect(_ core: KiwiCore) {
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
    }

    private func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)])
                .isSuccess
        )
    }

    private func sharedFill(_ core: KiwiCore) -> String? {
        core.guiConfigStore.load()?.look?.colors["kiwishelf.fill_color"]
    }

    @Test("a Keep of a follower writes its look to the shared one")
    func keepWritesTheSharedLook() throws {
        let core = try crossedCore()
        core.tiler.settings.kiwishelf.fillColor = odd
        try core.persistProfile(named: "Work", modes: nil)
        #expect(sharedFill(core) == odd)
        #expect(core.sharedLook?.colors["kiwishelf.fill_color"] == odd)
    }

    @Test("an own profile's Keep leaves the shared look alone")
    func ownKeepStaysOwn() throws {
        let core = try crossedCore()
        try core.profiles.save(profile("Odd", fill: odd))
        load("Odd", core)
        let before = sharedFill(core)
        core.tiler.settings.kiwishelf.fillColor = "#112233"
        try core.persistProfile(named: "Odd", modes: nil)
        #expect(sharedFill(core) == before)
    }

    @Test("a Save as copies the live profile's switch")
    func saveAsCopiesTheSwitch() throws {
        let core = try crossedCore()
        try core.persistProfile(named: "Copy of Work", modes: nil)
        #expect(try core.profiles.read(name: "Copy of Work").look == nil)
        try core.profiles.save(profile("Odd", fill: odd))
        load("Odd", core)
        try core.persistProfile(named: "Copy of Odd", modes: nil)
        #expect(try core.profiles.read(name: "Copy of Odd").look == .own)
    }

    @Test("before the crossing a follower's write seeds nothing")
    func noSharedLookNoWrite() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-shared-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        core.recordLookWrite(of: profile("New", look: nil))
        #expect(core.sharedLook == nil)
        #expect(core.guiConfigStore.load()?.look == nil)
    }

    @Test("a stored-profile Save commits a follower's look")
    func storedSaveCommits() throws {
        let core = try crossedCore()
        var edited = try core.loadGuiConfig(editing: "Work")
        edited.settings.kiwishelf.fillColor = odd
        try core.overwriteProfile(
            named: "Work",
            with: edited,
            writingRules: true
        )
        // The profile write alone never touches gui.json…
        #expect(sharedFill(core) != odd)
        core.commitSharedLook(ofProfile: "Work")
        // …its look half does.
        #expect(sharedFill(core) == odd)
    }

    @Test("a copy with an edited look keeps it as its own")
    func copyKeepsAnEditedLook() throws {
        let core = try crossedCore()
        var edited = try core.loadGuiConfig(editing: "Work")
        let same = try core.copyProfile(
            named: "Work",
            to: "Same",
            with: edited
        )
        #expect(try core.profiles.read(name: same).look == nil)
        edited.settings.kiwishelf.fillColor = odd
        let changed = try core.copyProfile(
            named: "Work",
            to: "Changed",
            with: edited
        )
        #expect(try core.profiles.read(name: changed).look == .own)
        #expect(sharedFill(core) != odd)
    }

    @Test("a follower's draft shows the shared look")
    func draftShowsTheSharedLook() throws {
        let core = try crossedCore()
        try core.profiles.save(profile("Stale", fill: odd, look: nil))
        let draft = try core.loadGuiConfig(editing: "Stale")
        #expect(draft.settings.kiwishelf.fillColor != odd)
        #expect(core.sharedLook?.isWorn(by: draft.settings) == true)
    }

    @Test("a built-in layout wears the shared look")
    func builtInWearsTheSharedLook() throws {
        let core = try crossedCore()
        core.tiler.settings.kiwishelf.fillColor = odd
        try core.persistProfile(named: "Work", modes: nil)
        let display = try #require(core.state.workspaces.allDisplays.first)
        let composed = try #require(
            ProfileComposition.compose(
                displays: [display],
                mainID: display.id
            )
        )
        core.apply(composed: composed, forceRetile: true)
        #expect(core.tiler.settings.kiwishelf.fillColor == odd)
    }
}
