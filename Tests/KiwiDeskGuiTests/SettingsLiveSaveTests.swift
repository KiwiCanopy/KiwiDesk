import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Save the "Live, not saved" rows promise (#2262), driven
/// through the real Settings Save over a real core: a live change
/// made while the window was away is listed on return, and Save
/// keeps it beside the draft's own edit — never the seed's old
/// value, which a whole-settings apply would put back.
@Suite("Live, not saved Save (#2262)", .serialized)
@MainActor
struct SettingsLiveSaveTests {
    /// "Odd" loaded on one 100x100 screen, keeping its own look,
    /// with Settings seeded from it.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-live-\(UUID().uuidString)")
        )
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
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(
            Profile(
                name: "Odd",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaces: ["1"],
                spaceModes: ["1": .bsp],
                settings: TilingSettings(),
                look: .own
            )
        )
        #expect(
            core.execute("load_profile", args: [.string("Odd")])
                .isSuccess
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    @Test("a dirty draft's Save keeps the live change it lists")
    func dirtySaveKeepsLive() throws {
        let model = try makeModel()
        let core = model.core
        let gap = model.config.settings.gapsGlobal.outer.top + 3
        model.config.settings.gapsGlobal.outer.top = gap
        #expect(model.isDirty)
        _ = core.execute("border.set_width", args: [.number(9)])

        model.refreshOwner()

        #expect(model.liveUnsaved)
        #expect(model.isDirty)
        #expect(model.primarySaveEnabled)
        model.updateActiveProfile()
        #expect(core.tiler.settings.borderStyle.width == 9)
        #expect(core.tiler.settings.gapsGlobal.outer.top == gap)
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.settings.borderStyle.width == 9)
        #expect(core.unsavedLiveSettings() == nil)
        #expect(!model.liveUnsaved)
    }

    @Test("a clean draft takes the live change and saves it")
    func cleanSaveKeepsLive() throws {
        let model = try makeModel()
        let core = model.core
        _ = core.execute("border.set_width", args: [.number(9)])

        model.refreshOwner()

        #expect(model.config.settings.borderStyle.width == 9)
        #expect(!model.isDirty)
        #expect(model.liveUnsaved)
        #expect(model.primarySaveEnabled)
        model.updateActiveProfile()
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.settings.borderStyle.width == 9)
        #expect(!model.liveUnsaved)
    }
}
