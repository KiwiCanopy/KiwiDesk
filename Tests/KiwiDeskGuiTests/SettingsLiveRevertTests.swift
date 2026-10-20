import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Revert on the pill's "Live, not saved" rows (#2411): a row's ↺
/// puts its own leaves back live through Core's revert, and the
/// pill's Revert takes every live row back with the draft. Drift
/// is left alone by ruling.
@Suite("Live, not saved Revert (#2411)", .serialized)
@MainActor
struct SettingsLiveRevertTests {
    /// "Odd" loaded on one 100x100 screen, keeping its own look,
    /// with Settings seeded from it.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-revert-\(UUID().uuidString)")
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

    private func liveRows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model).filter {
            $0.section == .live
        }
    }

    @Test("a row's ↺ reverts its own leaf live and writes nothing")
    func rowRevertsItsLeaf() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let core = model.core
        let width = core.tiler.settings.borderStyle.width
        _ = core.execute("border.set_width", args: [.number(9)])
        _ = core.execute("app_bar.set_title_cap", args: [.number(12)])
        model.refreshOwner()
        let border = try #require(
            liveRows(model).first { $0.key == .borders(.borderWidth) }
        )
        #expect(border.revert == .live)
        #expect(model.canRevert(border))

        model.revert(border)
        #expect(core.tiler.settings.borderStyle.width == width)
        #expect(core.tiler.settings.appBarStyle.titleCap == 12)
        let stored = try core.profiles.read(name: "Odd").settings
        #expect(stored.appBarStyle.titleCap != 12)
        #expect(liveRows(model).count == 1)
        #expect(!model.isDirty)
    }

    /// A draft seeded after the live change holds the live value; a
    /// clean draft re-reads after the row's revert, and a dirty one
    /// takes nothing, as a session-only write (`adoptLiveWrite`).
    @Test("the draft follows a live row's revert")
    func draftFollows() throws {
        LocalizationManager.shared.select("en")
        for dirty in [false, true] {
            let model = try makeModel()
            let core = model.core
            let width = core.tiler.settings.borderStyle.width
            _ = core.execute("border.set_width", args: [.number(9)])
            model.reload()
            #expect(model.config.settings.borderStyle.width == 9)
            if dirty {
                model.config.settings.appBarStyle.titleCap += 3
                model.recomputeDirty()
            }
            let cap = model.config.settings.appBarStyle.titleCap
            let row = try #require(liveRows(model).first)
            model.revert(row)
            #expect(core.tiler.settings.borderStyle.width == width)
            let shown = dirty ? 9 : width
            #expect(model.config.settings.borderStyle.width == shown)
            #expect(model.cleanConfig.settings.borderStyle.width == shown)
            #expect(model.config.settings.appBarStyle.titleCap == cap)
            #expect(model.isDirty == dirty)
        }
    }

    /// The draft's own ↺ never reaches live, and a live row has no
    /// way back once the target is a stored profile.
    @Test("a live row reverts only on the live target")
    func liveTargetOnly() throws {
        let model = try makeModel()
        var row = SettingsDiffRow.change(
            .borders(.borderWidth),
            label: "Width",
            old: nil,
            new: nil
        )
        row.revert = .live
        #expect(!model.canRevert(row))
        row.keepIDs = ["/settings/border/width"]
        #expect(model.canRevert(row))
        model.target = .storedProfile("Odd")
        #expect(!model.canRevert(row))
    }

    @Test("Revert takes the live rows back with the draft")
    func revertAllReachesLive() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let core = model.core
        let width = core.tiler.settings.borderStyle.width
        _ = core.execute("border.set_width", args: [.number(9)])
        model.refreshOwner()
        model.config.settings.appBarStyle.titleCap += 3
        model.recomputeDirty()
        #expect(model.isDirty)
        #expect(model.liveUnsaved)

        model.revertAll()
        #expect(core.tiler.settings.borderStyle.width == width)
        #expect(!model.isDirty)
        #expect(!model.liveUnsaved)
        #expect(SettingsDiffRowSource.rows(for: model).isEmpty)
    }

    /// The pill's Revert is the model's one revert-all, enabled
    /// while either side has a change; a live row draws its ↺.
    @Test("the pill and the live rows wire the revert")
    func revertIsWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let footer = try SourceScan.blankedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsFooter.swift"
            )
        )
        #expect(footer.contains("model.revertAll()"))
        #expect(!footer.contains("model.revert()"))
        #expect(
            footer.contains(".disabled(!model.isDirty && !model.liveUnsaved)")
        )
        let rows = try SourceScan.blankedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsDiffRowsView+Live.swift"
            )
        )
        #expect(rows.contains("RowRevertButton(row: row, group: false)"))
        #expect(rows.contains("revertLiveRow(row, among: shown, with: back)"))
        #expect(rows.contains("guard revert.performLive(row)"))
        let live = try SourceScan.blankedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsDiffRowSource+Live.swift"
            )
        )
        #expect(
            live.contains(
                "core.withUserMotion { core.revertUnsavedLive(ids) }"
            )
        )
        let verb = try SourceScan.blankedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDeskCore/Commands/KiwiCore+RevertSettings.swift"
            )
        )
        // Each half of the apply a setter makes (#2411).
        for needle in [
            "clearSessionShadows(from: current, to: back)",
            "retile(pass: .apply)",
            "refreshStickyReach()",
        ] {
            #expect(verb.contains(needle))
        }
    }
}
