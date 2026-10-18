import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A row's ↺ takes back its one change and nothing else (#792): a
/// draft holding one edit of every writer shape is reverted row by
/// row, and each step removes exactly the row it named. Locale
/// pinned per body (#740).
@MainActor
@Suite("Settings row revert (#792)")
struct SettingsRowRevertTests {
    private func baseline() -> GuiConfig {
        var config = GuiConfig()
        config.settings.bsp.override[SpaceID("1")] = BspOverride()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.floatRules = ["Info", "Notes"]
        config.appRules = ["com.apple.Safari": SpaceID("1")]
        return config
    }

    /// One edit per writer shape: a leaf, one side of a gap, two
    /// instances of one override field, a map entry, two Main
    /// Spaces, a rule list both ways with two added entries (one
    /// titled), and an added Space.
    private func edited() -> GuiConfig {
        var config = baseline()
        config.settings.borderStyle.width += 3
        config.settings.gapsGlobal.outer.top += 4
        config.settings.bsp.override[SpaceID("1")]?.splitRatioH = 0.7
        var second = BspOverride()
        second.splitRatioH = 0.3
        config.settings.bsp.override[SpaceID("2")] = second
        config.spaceModes[SpaceID("2")] = .grid
        config.mainSpaces = [SpaceID("1"), SpaceID("2")]
        config.appRules["com.apple.Notes"] = SpaceID("2")
        config.floatRules = [
            "Notes", "Calculator", "com.apple.finder:Info",
        ]
        config.spaces = [SpaceID("1"), SpaceID("2"), SpaceID("3")]
        return config
    }

    private func model() -> SettingsModel {
        let model = makeTestModel()
        model.cleanConfig = baseline()
        model.config = edited()
        model.cleanLuaSource = "-- a"
        model.luaSource = "-- b"
        return model
    }

    @Test("each ↺ removes its own row and no other")
    func eachRevertIsOneRow() throws {
        LocalizationManager.shared.select("en")
        let model = model()
        var rows = SettingsDiffRowSource.rows(for: model)
        #expect(rows.count >= 10)
        while let row = rows.first {
            #expect(
                model.canRevert(row),
                Comment(rawValue: "no ↺: \(row.id)")
            )
            guard model.canRevert(row) else { return }
            model.revert(row)
            let after = SettingsDiffRowSource.rows(for: model)
            // A row that stays would be retried forever: fail once.
            guard !after.contains(where: { $0.id == row.id }) else {
                Issue.record("still listed: \(row.id)")
                return
            }
            #expect(
                Set(after.map(\.id)) == Set(rows.dropFirst().map(\.id)),
                Comment(rawValue: "\(row.id) took others with it")
            )
            rows = after
        }
        #expect(model.config == model.cleanConfig)
        #expect(model.luaSource == model.cleanLuaSource)
    }

    @Test("a removed override entry comes back, an added one goes")
    func overrideEntriesSettle() {
        let model = model()
        var row = SettingsDiffRow.change(
            .layout(.bspOverrideSplitRatioH),
            instance: "2",
            label: "",
            old: nil,
            new: nil
        )
        row.revert = .census
        model.revert(row)
        #expect(model.config.settings.bsp.override[SpaceID("2")] == nil)
        #expect(
            model.config.settings.bsp.override[SpaceID("1")]?.splitRatioH
                == 0.7
        )
        // The other way: an entry the draft dropped comes back.
        model.config.settings.bsp.override[SpaceID("1")] = nil
        var first = row
        first.instance = "1"
        model.revert(first)
        #expect(
            model.config.settings.bsp.override[SpaceID("1")]
                == model.cleanConfig.settings.bsp.override[SpaceID("1")]
        )
    }

    @Test("a reach row takes the app's rule and its reach back")
    func ruleReachRevertsTheApp() {
        let model = model()
        model.reachEdits.reach[.space] = [
            "com.apple.notes": .shared(joining: [])
        ]
        var row = SettingsDiffRow.note(
            .appRules(.appRules),
            instance: "reach.new.com.apple.notes",
            label: "Notes",
            note: ""
        )
        row.revert = .ruleReach(app: "com.apple.notes")
        model.revert(row)
        #expect(model.config.appRules == model.cleanConfig.appRules)
        #expect(model.reachEdits.reach[.space]?["com.apple.notes"] == nil)
    }

    /// The real drift producer's row: a row no producer marked
    /// offers nothing, and drift is never the draft's to revert.
    @Test("a drift row offers no ↺")
    func driftRowHasNone() throws {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        model.activeProfile = "Desk"
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                count: 0,
                sets: [],
                isDefault: true,
                matchesLive: false,
                matchesConnectedCount: true,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        model.profileDirty = true
        let rows = SettingsDiffRowSource.rows(for: model)
        let drift = try #require(rows.first)
        #expect(drift.key == .screens(.fingerprints))
        #expect(!model.canRevert(drift))
    }
}
