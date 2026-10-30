import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Shared look switch's draft half (#1752): a pick is
/// staged, marks the draft dirty with one save-pill row per
/// profile, a tick back drops it, and a Save writes it through
/// Core's one door.
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

    @Test("Use the shared look paints the draft; taking it back restores")
    func usePaintsAndRestores() throws {
        let model = try model()
        model.core.crossWith(LookBody(of: TilingSettings()))
        model.lookReachStored["Home"] = false
        model.config.settings.kiwishelf.fillColor = "#0A0B0C"
        let before = model.config.settings
        model.stageLookSwitch("Home", .use)
        #expect(model.lookFollows["Home"] == true)
        let shared = try #require(model.core.sharedLook)
        #expect(shared.isWorn(by: model.config.settings))
        model.stageLookSwitch("Home", .own)
        #expect(model.lookReachEdits.isEmpty)
        #expect(model.config.settings == before)
    }

    /// One painted leaf reverted alone would land as an edit of the
    /// shared look at the Save, so the paint folds into its row.
    @Test("a Use paint is one pill row")
    func usePaintIsOneRow() throws {
        let model = try model()
        model.core.crossWith(LookBody(of: TilingSettings()))
        model.lookReachStored["Home"] = false
        model.config.settings.kiwishelf.fillColor = "#0A0B0C"
        model.cleanConfig = model.config
        model.stageLookSwitch("Home", .use)
        let rows = SettingsDiffRowSource.rows(for: model)
        #expect(rows.map(\.label) == ["Home"])
    }

    /// A paint taken back a leaf at a time (Simple's look row, a
    /// setting's ↺) would land the own look as the shared one, so
    /// the Save paints the shared look again.
    @Test("a Save paints a staged Use again")
    func saveRepaintsUse() throws {
        let model = try model()
        model.core.crossWith(LookBody(of: TilingSettings()))
        model.lookReachStored["Home"] = false
        model.config.settings.kiwishelf.fillColor = "#0A0B0C"
        let own = model.config.settings
        model.stageLookSwitch("Home", .use)
        model.config.settings = ShelfLook.unpicked(
            model.config.settings,
            to: own
        )
        let shared = try #require(model.core.sharedLook)
        #expect(model.saveLookReach())
        #expect(shared.isWorn(by: model.config.settings))
        #expect(model.core.sharedLook == shared)
    }

    @Test("Make this the shared look stages the source and its row")
    func makeStagesTheSource() throws {
        let model = try model()
        model.lookReachStored["Home"] = false
        model.stageLookSwitch("Home", .make)
        #expect(model.lookShare?.makes("Home") == true)
        #expect(model.lookReachDiffRows().map(\.label) == ["Home"])
        model.stageLookSwitch("Home", .own)
        #expect(model.lookShare == nil)
        #expect(model.lookReachEdits.isEmpty)
    }

    @Test("a Save of Make lands the own look as the shared one")
    func makeSaveLandsTheLook() throws {
        let model = try model()
        var home = try model.core.profiles.read(name: "Home")
        home.settings.kiwishelf.fillColor = "#0A0B0C"
        home.look = .own
        try model.core.profiles.write(home)
        model.core.crossWith(LookBody(of: TilingSettings()))
        model.resetLookReach()
        #expect(model.lookReachStored["Home"] == false)
        #expect(model.core.sharedLook != nil)
        // The page shows the draft's look, which is what lands.
        model.config.settings.kiwishelf.fillColor = "#0A0B0D"
        model.stageLookSwitch("Home", .make)
        #expect(model.saveLookReach())
        #expect(
            model.core.sharedLook?.colors["kiwishelf.fill_color"]
                == "#0A0B0D"
        )
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
