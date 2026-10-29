import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The pill's "Live, not saved" rows (#2262): a stored setting
/// changed live outside Settings is listed saved → live in its own
/// section, from both sides of Core's one reading, and a setting
/// the draft edits is the draft's row alone. Core's verdict is
/// stood in by hand here — its own suite, Save included, is
/// `UnsavedLiveSettingsTests` — and the wiring is the needles at
/// the end. Locale pinned per body (#740).
@MainActor
@Suite("Live, not saved rows (#2262)")
struct SettingsLiveRowsTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    /// A clean live draft over Core's reading: saved border width
    /// 5 while live draws 9.
    private func liveModel() -> SettingsModel {
        let model = makeTestModel(root: .advanced)
        model.cleanConfig.settings.borderStyle.width = 9
        model.config = model.cleanConfig
        var saved = model.cleanConfig.settings
        saved.borderStyle.width = 5
        model.unsavedLive = UnsavedLiveSettings(
            saved: saved,
            live: model.cleanConfig.settings,
            leaves: [:]
        )
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
        #expect(!model.isDirty)
    }

    /// The live side is Core's, never the draft's baseline: an
    /// outside write that moved `cleanConfig` without a new
    /// reading lists nothing it did not judge.
    @Test("the live side is Core's reading, not the baseline")
    func liveSideIsCores() {
        let model = liveModel()
        model.cleanConfig.settings.gapsGlobal.outer.top += 3
        model.config = model.cleanConfig
        let rows = SettingsDiffRowSource.rows(for: model)
        #expect(rows.map(\.key) == [.borders(.borderWidth)])
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

    @Test("nothing behind live lists nothing")
    func noVerdictListsNothing() {
        let model = liveModel()
        model.unsavedLive = nil
        #expect(SettingsDiffRowSource.rows(for: model).isEmpty)
    }

    /// Wiring the behaviour suites cannot see: Core is asked again
    /// at the seed, a window-key return, a captured or adopted
    /// outside write — the rows' freshness, while the Save's own
    /// rebase is `SettingsLiveSaveTests`'; the one refresh gates on
    /// the live target; the pill
    /// and the active profile's Save count a live row as work; the
    /// panel's draft list leaves live rows to the pill. Shape, not
    /// value: each needle is the seam's name at its use site.
    @Test("refresh points, pill and Save read the live verdict")
    func wiringReadsTheVerdict() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let wants: [String: [String]] = [
            "SettingsModel+EditTarget.swift": [
                "refreshProfiles()refreshUnsavedLive()"
            ],
            "SettingsModel+Refresh.swift": [
                "}else{refreshUnsavedLive()}"
            ],
            "SettingsModel+LiveWrite.swift": [
                "guardpersistedelse{refreshUnsavedLive()return}",
                "recomputeDirty()refreshUnsavedLive()}",
            ],
            "SettingsWindowController.swift": [
                "model.adoptCapturedSpaces()}model.refreshUnsavedLive()"
            ],
            "SettingsDiffRowSource+Live.swift": [
                "unsavedLive=target==.live&&!editingLua"
                    + "?core.unsavedLiveSettings():nil"
            ],
            "SettingsFooter.swift": [
                "model.isDirty||model.liveDrift||model.liveUnsaved"
            ],
            "SettingsModel+SaveAction.swift": [
                "(isDirty||profileDirty||liveUnsaved)"
            ],
            "SettingsDetailPanel.swift": [
                "rows+=liveRows(for:model,leaving:diff.changedSettings)",
                "rows(for:model).filter{$0.section==.draft}",
            ],
        ]
        for (file, needles) in wants {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(rawValue: "\(file) lost \(needle)")
                )
            }
        }
    }
}
