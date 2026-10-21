import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Save the "Live, not saved" rows promise (#2262), driven
/// through the real Settings Save over a real core: a Settings Save
/// lays only the draft's own edits over live as it is AT the Save,
/// so a live change made since the seed is kept — listed or not,
/// refreshed or not — and the draft's own edit of the same setting
/// is what it commits.
@Suite("Live, not saved Save (#2262)", .serialized)
@MainActor
struct SettingsLiveSaveTests {
    /// "Odd" loaded on one 100x100 screen, keeping its own look,
    /// with Settings seeded from it.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
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

    private func storedWidth(_ model: SettingsModel) throws -> CGFloat {
        try model.core.profiles.read(name: "Odd").settings
            .borderStyle.width
    }

    @Test("a dirty draft's Save keeps the live change it lists")
    func dirtySaveKeepsLive() throws {
        let model = try makeModel()
        let core = model.core
        let gap = model.config.settings.gapsGlobal.outer.top + 3
        model.config.settings.gapsGlobal.outer.top = gap
        _ = core.execute("border.set_width", args: [.number(9)])

        model.refreshOwner()

        #expect(model.liveUnsaved)
        #expect(model.primarySaveEnabled)
        model.updateActiveProfile()
        #expect(core.tiler.settings.borderStyle.width == 9)
        #expect(core.tiler.settings.gapsGlobal.outer.top == gap)
        #expect(try storedWidth(model) == 9)
        #expect(core.unsavedLiveSettings() == nil)
        #expect(!model.liveUnsaved)
    }

    /// A Lua-bound hotkey or timer changes a setting while Settings
    /// stays key, so no refresh runs: the Save still keeps it.
    @Test("a live change no refresh saw is still kept")
    func unrefreshedChangeIsKept() throws {
        let model = try makeModel()
        let core = model.core
        model.config.settings.gapsGlobal.outer.top += 3
        _ = core.execute("border.set_width", args: [.number(9)])

        model.updateActiveProfile()

        #expect(core.tiler.settings.borderStyle.width == 9)
        #expect(try storedWidth(model) == 9)
    }

    @Test("the draft's edit of a live-changed setting is committed")
    func draftEditWinsAtSave() throws {
        let model = try makeModel()
        let core = model.core
        model.config.settings.borderStyle.width = 7
        _ = core.execute("border.set_width", args: [.number(9)])
        model.refreshOwner()

        model.updateActiveProfile()

        #expect(core.tiler.settings.borderStyle.width == 7)
        #expect(try storedWidth(model) == 7)
    }

    /// A stored profile's draft is another file: Core's live rows
    /// are never its to list.
    @Test("a stored profile's draft lists no live rows")
    func storedTargetListsNothing() throws {
        let model = try makeModel()
        _ = model.core.execute("border.set_width", args: [.number(9)])
        model.refreshOwner()
        #expect(model.liveUnsaved)

        model.target = .storedProfile("Odd")
        model.refreshUnsavedLive()

        #expect(model.unsavedLive == nil)
        #expect(!model.liveUnsaved)
    }

    @Test("a clean draft's Save keeps the live change it lists")
    func cleanSaveKeepsLive() throws {
        let model = try makeModel()
        let core = model.core
        _ = core.execute("border.set_width", args: [.number(9)])

        model.refreshOwner()

        #expect(!model.isDirty)
        #expect(model.liveUnsaved)
        #expect(model.primarySaveEnabled)
        model.updateActiveProfile()
        #expect(try storedWidth(model) == 9)
        #expect(!model.liveUnsaved)
    }
}
