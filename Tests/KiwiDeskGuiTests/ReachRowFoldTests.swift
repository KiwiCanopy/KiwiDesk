import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Profiles that changed exactly as the edited one did read as its
/// row's reach rather than a row each (#792, owner 2026-10-18);
/// one that changed otherwise keeps a row of its own.
@Suite("Reach rows fold into the edited row (#792)", .serialized)
@MainActor
struct ReachRowFoldTests {
    /// gui.json opens Mail in Space 1; Work is loaded and edited,
    /// `others` are stored, and `leavers` leave Mail out.
    private func makeModel(
        others: [String],
        leavers: Set<String> = []
    ) throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.appRules = ["mail": SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work", nil))
        for name in others {
            let leaves = leavers.contains(name)
            try core.profiles.write(
                profile(
                    name,
                    leaves ? AppRuleOverride(rules: ["mail": nil]) : nil
                )
            )
        }
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String, _ rules: AppRuleOverride?)
        -> Profile
    {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1"), SpaceID("2")],
            spaceModes: [:],
            settings: TilingSettings(),
            appRules: rules
        )
    }

    private func mailRows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model).filter {
            $0.subject?.family == .space
        }
    }

    @Test("every profile changed alike reads as one row")
    func alikeFolds() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel(others: ["Home", "Away"])
        model.config.appRules["mail"] = SpaceID("2")

        // Vacuity: the two other profiles do have a reach row.
        #expect(model.reachDiffRows().count == 1)
        let rows = mailRows(model)
        #expect(rows.count == 1)
        #expect(rows.first?.reach == RuleReachWords.allProfiles)
        #expect(rows.first?.revert == .census)
    }

    @Test("a profile that changed otherwise keeps its own row")
    func differingSplits() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel(
            others: ["Home", "Spare", "Away"],
            leavers: ["Home", "Spare"]
        )
        model.config.appRules["mail"] = SpaceID("2")
        // The differing group is the larger, so it sorts first.
        model.setProfile(.space, "mail", "Home", true)
        model.setProfile(.space, "mail", "Spare", true)

        let rows = mailRows(model)
        #expect(rows.count == 2)
        let own = try #require(rows.first { $0.reach != nil })
        #expect(own.reach?.contains("Away") == true)
        #expect(own.reach?.contains("Home") == false)
        #expect(own.reach?.contains("Spare") == false)
        let home = try #require(rows.first { $0.reach == nil })
        #expect(home.label.contains("Home"))
        #expect(home.oldValue == L("app_rules.reach.diff.none", "No rule"))
    }

    @Test("profiles that changed alike share one row")
    func alikeGroup() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel(others: ["Home", "Away", "Spare"])
        model.config.appRules["mail"] = SpaceID("2")

        let rows = model.reachDiffRows()
        #expect(rows.count == 1)
        #expect(
            rows.first?.label.contains(
                RuleReachWords.group(
                    ["Away", "Home", "Spare"]
                )
            ) == true
        )
    }
}
