import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// One control, one change (#2450): the settings one control
/// writes together are one save-pill row while they agree, and one
/// row per changed member otherwise. Main-actor cost: one test
/// model per test, no scans. Locale pinned per body (#740).
@MainActor
@Suite("Summary groups fold in the save pill (#2450)")
struct SettingsSummaryGroupTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func gapRows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model).filter {
            if case .gaps = $0.key { return true }
            return false
        }
    }

    @Test("every group is a master over members under its path")
    func groupsAreWellFormed() {
        for (master, members) in SettingKey.summaryGroups {
            #expect(members.count > 1)
            #expect(SettingsRevertRegister.writers[master] != nil)
            let base = master.id.replacingOccurrences(
                of: " (master)",
                with: ""
            )
            for member in members {
                #expect(member.id.hasPrefix(base + "."), "\(member)")
                #expect(member.summaryMaster == master)
            }
            // A master writing its members unconditionally would
            // never let them list apart.
            #expect(SettingKey.masterWrites[master] == nil)
        }
    }

    @Test("the outer slider's nudge is one Outer gap row")
    func outerNudgeIsOneRow() throws {
        pinEnglish()
        let model = makeTestModel()
        model.config.settings.gapsGlobal.outer = .init(
            top: 14,
            bottom: 14,
            left: 14,
            right: 14
        )
        let rows = gapRows(model)
        let row = try #require(rows.first)
        #expect(rows.count == 1, "\(rows.map(\.key))")
        #expect(row.key == .gaps(.outer))
        #expect(row.newValue == "14 pt")
        #expect(row.revert == .census)
    }

    @Test("the inner slider's nudge is one Inner gap row")
    func innerNudgeIsOneRow() {
        let model = makeTestModel()
        model.config.settings.gapsGlobal.inner.horizontal = 3
        model.config.settings.gapsGlobal.inner.vertical = 3
        #expect(gapRows(model).map(\.key) == [.gaps(.inner)])
    }

    @Test("edges that differ list each changed edge alone")
    func differingEdgesListApart() {
        let model = makeTestModel()
        model.config.settings.gapsGlobal.outer.top = 2
        model.config.settings.gapsGlobal.outer.left = 4
        #expect(
            gapRows(model).map(\.key)
                == [.gaps(.outerTop), .gaps(.outerLeft)]
        )
    }

    /// The fold reads every member, not only the changed ones: one
    /// edge brought level with the rest is the whole group's row.
    @Test("one edge brought level with the rest folds the group")
    func levellingEdgeFolds() {
        let model = makeTestModel()
        model.cleanConfig.settings.gapsGlobal.outer.right = 4
        model.config = model.cleanConfig
        model.config.settings.gapsGlobal.outer.right =
            model.config.settings.gapsGlobal.outer.top
        #expect(gapRows(model).map(\.key) == [.gaps(.outer)])
    }

    @Test("a folded row's revert takes every edge back")
    func foldedRevertTakesAll() throws {
        let model = makeTestModel()
        let clean = model.cleanConfig.settings.gapsGlobal.outer
        model.config.settings.gapsGlobal.outer = .init(
            top: 30,
            bottom: 30,
            left: 30,
            right: 30
        )
        let row = try #require(gapRows(model).first)
        SettingsRevertRegister.writers[row.key]?.apply(model, nil)
        #expect(model.config.settings.gapsGlobal.outer == clean)
        #expect(SettingsRevertRegister.writers[row.key]?.takesGroup != true)
    }

    @Test("a live change of every edge is one live row")
    func liveRowFolds() throws {
        let model = makeTestModel()
        var saved = model.cleanConfig.settings
        saved.gapsGlobal.outer = .init(top: 2, bottom: 2, left: 2, right: 2)
        var live = model.cleanConfig.settings
        live.gapsGlobal.outer = .init(top: 9, bottom: 9, left: 9, right: 9)
        model.cleanConfig.settings = live
        model.config = model.cleanConfig
        // Each leaf is `saved` with that one edge live, as Core
        // hands it over.
        var leaves: [String: TilingSettings] = [:]
        let edges: [(String, WritableKeyPath<Gaps.Outer, CGFloat>)] = [
            ("top", \.top), ("bottom", \.bottom),
            ("left", \.left), ("right", \.right),
        ]
        for (name, edge) in edges {
            var one = saved
            one.gapsGlobal.outer[keyPath: edge] = 9
            leaves["gap.global.outer.\(name)"] = one
        }
        model.unsavedLive = UnsavedLiveSettings(
            saved: saved,
            live: live,
            leaves: leaves
        )
        let rows = SettingsDiffRowSource.rows(for: model)
        let row = try #require(rows.first)
        #expect(rows.count == 1, "\(rows.map(\.key))")
        #expect(row.key == .gaps(.outer))
        #expect(row.section == .live)
        // Its Keep carries the leaves of every edge.
        #expect(row.keepIDs.count == 4)
    }
}
