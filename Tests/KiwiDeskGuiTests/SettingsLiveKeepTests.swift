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
    /// Two layouts' indicator rows each own their own leaf, so
    /// keeping Monocle's never keeps Scrolling's.
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

    /// One key drawing a row per Space: each row still keeps only
    /// its own Space's leaf.
    @Test("rows of one key keep apart")
    func rowsOfOneKeyKeepApart() {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        let saved = model.cleanConfig.settings
        let gaps = saved.gapsGlobal
        var one = saved
        one.gapsOverride[SpaceID("1")] = gaps
        var two = saved
        two.gapsOverride[SpaceID("2")] = gaps
        var live = one
        live.gapsOverride[SpaceID("2")] = gaps
        model.cleanConfig.settings = live
        model.config = model.cleanConfig
        model.unsavedLive = UnsavedLiveSettings(
            saved: saved,
            live: live,
            leaves: ["a": one, "b": two]
        )
        let rows = SettingsDiffRowSource.rows(for: model)
            .filter { $0.section == .live }
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.key)).count == 1)
        #expect(Set(rows.map(\.keepIDs)) == [["a"], ["b"]])
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

        let kept = model.keepLive(border.keepIDs)
        #expect(kept?.refused.isEmpty == true)
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

    /// A keep whose write cannot land leaves the row listed with
    /// its reason, and answers it.
    @Test("a refused keep stays listed with its reason")
    func refusedKeepStays() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let core = model.core
        _ = core.execute("border.set_width", args: [.number(9)])
        model.refreshOwner()
        let row = try #require(
            SettingsDiffRowSource.rows(for: model)
                .first { $0.section == .live }
        )
        let file = core.configDirectory
            .appendingPathComponent("profiles/Odd.json")
        try FileManager.default.setAttributes(
            [.immutable: true],
            ofItemAtPath: file.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.immutable: false],
                ofItemAtPath: file.path
            )
        }
        let outcome = try #require(model.keepLive(row.keepIDs))
        #expect(!outcome.refused.isEmpty)
        #expect(!model.liveKeepRefusals.isEmpty)
        let stays = try #require(
            SettingsDiffRowSource.rows(for: model)
                .first { $0.section == .live }
        )
        let keep = LiveKeep(
            profile: "Odd",
            refusals: model.liveKeepRefusals
        ) { _ in nil }
        #expect(keep.refusal(for: stays) != nil)
    }

    /// Each refusal reason reads its own sentence.
    @Test("a conflicting leaf and an unwritten one read apart")
    func refusalWording() {
        LocalizationManager.shared.select("en")
        var row = SettingsDiffRow.change(
            .borders(.borderWidth),
            label: "Width",
            old: nil,
            new: nil
        )
        row.keepIDs = ["x"]
        func text(_ reason: NotKeepable) -> String? {
            LiveKeep(profile: "Odd", refusals: ["x": reason]) { _ in nil }
                .refusal(for: row)
        }
        #expect(text(.conflicting)?.contains("doesn't fit") == true)
        #expect(text(.notWritten) == "Couldn't keep this setting.")
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
        let list = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/SettingsDiffRowsView.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            list.contains(
                "LiveKeepButton(row:row,keep:keep){"
                    + "keepRow(row,among:shown,with:keep)}"
            )
        )
        #expect(
            list.contains(
                "guardkeep.keep(row.keepIDs),"
                    + "SettingsInputSource.movesFocus,letnext"
            )
        )
        #expect(
            list.contains(
                "ifletkeep,live.count>1{"
                    + "LiveKeepAllButton(rows:live,keep:keep)"
            )
        )
    }
}
