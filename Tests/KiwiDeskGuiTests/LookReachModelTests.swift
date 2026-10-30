import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Shared look switch (#1752, #2820): the page's switch writes
/// at once over a clean draft and refuses a dirty one; a staged
/// switch marks the draft dirty with one save-pill row per profile,
/// a switch back drops it, and a Save writes it through Core's door.
@Suite("Look reach model (#1752)", .serialized)
@MainActor
struct LookReachModelTests {
    private func model() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-lookreach-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for name in ["Work", "Home"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["\(name):1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            )
        }
        let model = makeTestModel(core: core)
        model.resetLookReach()
        model.recomputeDirty()
        return model
    }

    @Test("a tick is staged, dirty, and one row")
    func tickIsStaged() throws {
        let model = try model()
        #expect(model.lookFollows == ["Work": true, "Home": true])
        #expect(!model.isDirty)
        model.setLookFollows("Home", false)
        #expect(model.lookFollows["Home"] == false)
        #expect(model.isDirty)
        #expect(model.lookReachDiffRows().map(\.label) == ["Home"])
    }

    @Test("a tick back to what is stored leaves nothing unsaved")
    func tickBackIsClean() throws {
        let model = try model()
        model.setLookFollows("Home", false)
        model.setLookFollows("Home", true)
        #expect(model.lookReachEdits.isEmpty)
        #expect(!model.isDirty)
    }

    /// A stored own Home with a fill of its own, beside the shared
    /// look Work follows.
    private func ownHome(_ model: SettingsModel) throws {
        var home = try model.core.profiles.read(name: "Home")
        home.settings.kiwishelf.fillColor = "#0A0B0C"
        home.look = .own
        try model.core.profiles.write(home)
        model.core.crossWith(LookBody(of: TilingSettings()))
        model.resetLookReach()
        model.recomputeDirty()
    }

    @Test("Use writes at once and takes the shared look")
    func useWritesAtOnce() throws {
        let model = try model()
        try ownHome(model)
        let shared = try #require(model.core.sharedLook)
        #expect(model.applyLookSwitch("Home", .use))
        let home = try model.core.profiles.read(name: "Home")
        #expect(home.look == nil)
        #expect(shared.isWorn(by: home.settings))
        #expect(model.core.sharedLook == shared)
        #expect(model.lookReachStored["Home"] == true)
    }

    @Test("Make lands the look the page shows as the shared one")
    func makeLandsTheShownLook() throws {
        let model = try model()
        try ownHome(model)
        model.config.settings.kiwishelf.fillColor = "#0A0B0D"
        model.cleanConfig = model.config
        model.recomputeDirty()
        #expect(model.applyLookSwitch("Home", .make))
        #expect(
            model.core.sharedLook?.colors["kiwishelf.fill_color"]
                == "#0A0B0D"
        )
        #expect(try model.core.profiles.read(name: "Home").look == nil)
    }

    @Test("This profile only writes at once")
    func ownWritesAtOnce() throws {
        let model = try model()
        #expect(model.applyLookSwitch("Home", .own))
        #expect(try model.core.profiles.read(name: "Home").look == .own)
    }

    @Test("a dirty draft refuses the switch and writes nothing")
    func dirtyRefuses() throws {
        let model = try model()
        model.config.settings.kiwishelf.fillColor = "#0A0B0E"
        model.recomputeDirty()
        #expect(model.isDirty)
        #expect(!model.applyLookSwitch("Home", .own))
        #expect(try model.core.profiles.read(name: "Home").look == nil)
    }

    @Test("a Save writes the ticks and clears them")
    func saveWrites() throws {
        let model = try model()
        model.setLookFollows("Home", false)
        #expect(model.saveLookReach())
        #expect(model.lookReachEdits.isEmpty)
        #expect(try model.core.profiles.read(name: "Home").look == .own)
        #expect(model.lookReachStored["Home"] == false)
    }
}
