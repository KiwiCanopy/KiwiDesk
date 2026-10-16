import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The pill's "Live, not saved" rows (#2262): a stored setting
/// changed live outside Settings is listed saved → live in its own
/// section, Save keeps it, and a setting the draft edits is the
/// draft's row alone. Core's verdict is stood in by hand here — its
/// own suite is `UnsavedLiveSettingsTests` — and the wiring from
/// `reload()` is the needle at the end. Locale pinned per body
/// (#740).
@MainActor
@Suite("Live, not saved rows (#2262)")
struct SettingsLiveRowsTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    /// A clean live draft whose saved border width is 5 while live
    /// draws 9.
    private func liveModel() -> SettingsModel {
        let model = makeTestModel()
        model.cleanConfig.settings.borderStyle.width = 9
        model.config = model.cleanConfig
        var saved = model.cleanConfig.settings
        saved.borderStyle.width = 5
        model.savedBehindLive = saved
        return model
    }

    @Test("a live change is a live row, saved → live")
    func liveChangeIsARow() throws {
        pinEnglish()
        let model = liveModel()
        let rows = SettingsDiffRowSource.rows(for: model)
        let row = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(row.key == .borders(.borderWidth))
        #expect(row.section == .live)
        #expect(row.id != row.key.id)
        #expect(row.oldValue?.contains("5") == true)
        #expect(row.newValue?.contains("9") == true)
        #expect(model.liveUnsaved)
        #expect(!model.isDirty)
    }

    @Test("the draft's edit of the same setting wins")
    func draftEditWins() throws {
        pinEnglish()
        let model = liveModel()
        model.config.settings.borderStyle.width = 7
        let rows = SettingsDiffRowSource.rows(for: model)
        #expect(rows.count == 1)
        #expect(rows.first?.section == .draft)
        #expect(rows.first?.newValue?.contains("7") == true)
    }

    @Test("a stored target lists no live rows")
    func storedTargetListsNothing() {
        let model = liveModel()
        model.target = .storedProfile("Other")
        #expect(SettingsDiffRowSource.rows(for: model).isEmpty)
        #expect(!model.liveUnsaved)
    }

    @Test("nothing behind live lists nothing")
    func noVerdictListsNothing() {
        let model = liveModel()
        model.savedBehindLive = nil
        #expect(SettingsDiffRowSource.rows(for: model).isEmpty)
        #expect(!model.liveUnsaved)
    }

    /// Wiring the behaviour suites cannot see: the seed reads
    /// Core's verdict, and the pill and the active profile's Save
    /// count a live row as work. Shape, not value: each needle is
    /// the seam's name at its use site.
    @Test("seed, pill and Save read the live verdict")
    func wiringReadsTheVerdict() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let wants: [String: String] = [
            "SettingsModel+EditTarget.swift":
                "savedBehindLive=target==.live&&!editingLua"
                + "?core.savedSettingsBehindLive():nil",
            "SettingsFooter.swift":
                "model.isDirty||model.liveDrift||model.liveUnsaved",
            "SettingsModel+SaveAction.swift":
                "(isDirty||profileDirty||liveUnsaved)",
            "SettingsDetailPanel.swift":
                "rows+=liveRows(for:model,leaving:diff.changedSettings)",
        ]
        for (file, needle) in wants {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            #expect(
                source.contains(needle),
                Comment(rawValue: "\(file) no longer reads the verdict")
            )
        }
    }
}
