import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Keep on the pill's "Live, not saved" rows (#2368): each row
/// keeps exactly the leaves it narrates, through Core's keep, and
/// the rows it did not keep stay listed.
@Suite("Live, not saved Keep (#2368)", .serialized)
@MainActor
struct SettingsLiveKeepTests {
    /// One key draws a row per layout; each row owns its own leaf,
    /// so keeping Monocle's never keeps Scrolling's.
    @Test("a row keeps its own leaf, never its sibling's")
    func rowsKeepApart() throws {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        let saved = model.cleanConfig.settings
        var monocle = saved
        monocle.monocle.appBar.activeIndicator = .edgeMark
        var scrolling = saved
        scrolling.scrolling.appBar.activeIndicator = .edgeMark
        var live = monocle
        live.scrolling.appBar.activeIndicator = .edgeMark
        model.cleanConfig.settings = live
        model.config = model.cleanConfig
        model.unsavedLive = UnsavedLiveSettings(
            saved: saved,
            live: live,
            leaves: ["m": monocle, "s": scrolling]
        )
        let rows = SettingsDiffRowSource.rows(for: model)
            .filter { $0.section == .live }
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.keepIDs)) == [["m"], ["s"]])
    }

    /// "Odd" loaded on one 100x100 screen, keeping its own look,
    /// with Settings seeded from it.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-keep-\(UUID().uuidString)")
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

    @Test("Keep writes one row and leaves the others listed")
    func keepWritesOneRow() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let core = model.core
        _ = core.execute("border.set_width", args: [.number(9)])
        _ = core.execute("app_bar.set_title_cap", args: [.number(12)])
        model.refreshOwner()
        let rows = SettingsDiffRowSource.rows(for: model)
            .filter { $0.section == .live }
        let border = try #require(
            rows.first { $0.key == .borders(.borderWidth) }
        )
        #expect(rows.count == 2)
        #expect(!border.keepIDs.isEmpty)

        #expect(model.keepLive(border.keepIDs))
        let stored = try core.profiles.read(name: "Odd").settings
        #expect(stored.borderStyle.width == 9)
        #expect(stored.appBarStyle.titleCap != 12)
        let left = SettingsDiffRowSource.rows(for: model)
            .filter { $0.section == .live }
        #expect(left.map(\.key) != [.borders(.borderWidth)])
        #expect(left.count == 1)
        #expect(model.liveKeepRefusals.isEmpty)
        #expect(!model.isDirty)
    }

    /// The pill offers Keep on the live target alone, through the
    /// model's one door.
    @Test("the popover wires the Keep")
    func keepIsWired() throws {
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/SettingsFooter+Unsaved.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains("keep:liveKeep"))
        #expect(source.contains("guardmodel.target==.live"))
        #expect(source.contains("model.keepLive(ids)"))
    }
}
