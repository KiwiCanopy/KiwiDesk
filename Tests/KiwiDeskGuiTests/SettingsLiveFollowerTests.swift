import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A profile wearing the shared look keeps a per-layout App Bar
/// indicator set live (#2368, owner ruling a): wearing the look is
/// no pick, so a Save or a Keep holds the value and the live row
/// clears.
@Suite("Live rows on a shared-look profile (#2368)", .serialized)
@MainActor
struct SettingsLiveFollowerTests {
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-follow-\(UUID().uuidString)")
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
        var gui = GuiConfig()
        gui.look = LookBody(of: TilingSettings())
        try core.guiConfigStore.save(gui)
        try core.profiles.save(
            Profile(
                name: "Odd",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaces: ["1"],
                spaceModes: ["1": .monocle],
                settings: TilingSettings()
            )
        )
        core.prepareSharedLook()
        #expect(
            core.execute("load_profile", args: [.string("Odd")])
                .isSuccess
        )
        let model = makeTestModel(core: core)
        model.reload()
        _ = core.execute(
            "monocle.set_app_bar_active_indicator",
            args: [.string("edge_mark")]
        )
        model.refreshOwner()
        return model
    }

    @Test("Save keeps a per-layout indicator on a follower")
    func saveKeepsIt() throws {
        let model = try makeModel()
        #expect(try model.core.profiles.read(name: "Odd").look == nil)
        #expect(model.liveUnsaved)
        model.updateActiveProfile()
        #expect(model.core.unsavedLiveSettings() == nil)
        #expect(!model.liveUnsaved)
        let stored = try model.core.resolvedSettings(
            of: model.core.profiles.read(name: "Odd")
        )
        #expect(stored.monocle.appBar.activeIndicator == .edgeMark)
    }

    @Test("Keep keeps a per-layout indicator on a follower")
    func keepKeepsIt() throws {
        let model = try makeModel()
        let row = try #require(
            SettingsDiffRowSource.rows(for: model)
                .first { $0.section == .live }
        )
        let outcome = model.keepLive(row.keepIDs)
        #expect(outcome?.refused.isEmpty == true)
        // A per-layout indicator is the profile's, not the look's.
        #expect(outcome?.sharedLook == false)
        #expect(!model.liveUnsaved)
    }

    /// A look leaf on a follower lands in the shared look, and the
    /// outcome says so, which the spoken sentence reads.
    @Test("a kept look leaf on a follower reports the shared look")
    func lookLeafReportsSharedLook() throws {
        let model = try makeModel()
        _ = model.core.execute("border.set_width", args: [.number(9)])
        model.refreshOwner()
        let row = try #require(
            SettingsDiffRowSource.rows(for: model)
                .first { $0.key == .borders(.borderWidth) }
        )
        let outcome = model.keepLive(row.keepIDs)
        #expect(outcome?.refused.isEmpty == true)
        #expect(outcome?.sharedLook == true)
    }

    /// `look.apply` is a pick, never a wear (#2368).
    @Test("the look verb picks, clearing a per-layout indicator")
    func lookVerbPicks() {
        let core = makeTestCore()
        core.tiler.settings.monocle.appBar.activeIndicator = .edgeMark
        core.wearLook(LookBody(of: TilingSettings()).named("Plain"))
        #expect(core.tiler.settings.monocle.appBar.activeIndicator == nil)
    }

    @Test("wearing keeps every per-layout indicator, a pick clears")
    func pickClears() {
        let leaves = TilingSettings.layoutIndicatorLeaves
        #expect(leaves.contains(\.monocle.appBar.activeIndicator))
        #expect(leaves.contains(\.scrolling.appBar.activeIndicator))
        let look = LookBody(of: TilingSettings())
        for leaf in TilingSettings.layoutIndicatorLeaves {
            var settings = TilingSettings()
            settings[keyPath: leaf] = .edgeMark
            #expect(look.worn(over: settings)[keyPath: leaf] == .edgeMark)
            #expect(look.isWorn(by: settings))
            var picked = settings
            look.named("").admitted.apply(to: &picked)
            #expect(picked[keyPath: leaf] == nil)
        }
    }
}
