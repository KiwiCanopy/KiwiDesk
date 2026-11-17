import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A bare Space row the user removed stays removed when a titled
/// rule is added from a titled row (#3415): the owner's sequence on
/// the live page, through the section's own writes, Save
/// (`updateActiveProfile`) and a reload.
@Suite("A removed bare Space row stays gone (#3415)", .serialized)
@MainActor
struct SpaceRuleBareStaysGoneTests {
    private let app = "com.brave.browser"

    private var bare: SpaceRuleRow { SpaceRuleRow(app: app, fragment: nil) }
    private var work: SpaceRuleRow { SpaceRuleRow(app: app, fragment: "Work") }

    /// Work loaded, Home stored; the app's bare and titled rules in
    /// the shared base, or in Work's own override.
    private func makeModel(shared: Bool) throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        if shared {
            config.appRules = [app: "1"]
            config.titledAppRules = [work.key: "2"]
        }
        try core.guiConfigStore.save(config)
        var loaded = profile("Work")
        if !shared {
            loaded.appRules = AppRuleOverride(rules: [app: "1"])
            loaded.titledAppRules = AppRuleOverride(rules: [work.key: "2"])
        }
        try core.profiles.save(loaded)
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1"), SpaceID("2")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    /// The trash on the bare row, then Add Rule… on the titled row:
    /// the section's `deleteSpace` and the scope cell's commit.
    private func removeBareThenAdd(
        _ model: SettingsModel,
        _ removal: RuleRemoval
    ) throws {
        model.recordRemoval(.space, app, removal)
        SpaceRuleEdit.drop(bare, from: &model.config)
        let space = try #require(
            SpaceRuleRows.space(of: work, in: model.config)
        )
        SpaceRuleEdit.addTitled(
            "Job",
            for: app,
            in: space,
            config: &model.config
        )
    }

    private func rows(_ model: SettingsModel) -> [SpaceRuleRow] {
        SpaceRuleRows.groups(model.config, apps: [app]).flatMap { $0 }
    }

    @Test(
        "the bare row stays out of the draft, the Save and the reload",
        arguments: [true, false]
    )
    func staysGone(shared: Bool) throws {
        let model = try makeModel(shared: shared)
        #expect(rows(model).contains(bare))
        try removeBareThenAdd(model, .here)
        let job = SpaceRuleRow(app: app, fragment: "Job")
        #expect(rows(model) == [work, job] || rows(model) == [job, work])
        #expect(model.encodedReach?.appRules.resolved(for: "Work")[app] == nil)

        model.updateActiveProfile()
        model.reload()
        #expect(!rows(model).contains(bare))
        #expect(Set(rows(model)) == [work, job])
    }

    @Test("on a stored profile's page, the Save leaves it out too")
    func storedPageStaysGone() throws {
        let model = try makeModel(shared: true)
        model.selectEditTarget("Home")
        #expect(rows(model).contains(bare))
        try removeBareThenAdd(model, .here)
        model.saveEditedProfile()
        let apps = model.encodedReach?.appRules
        #expect(apps?.resolved(for: "Home")[app] == nil)
        #expect(apps?.resolved(for: "Work")[app] == "1")
        let titled = model.encodedReach?.titledAppRules
        let job = SpaceRuleRow(app: app, fragment: "Job")
        #expect(titled?.resolved(for: "Home")[job.key] == "2")
    }

    @Test("removed everywhere, no profile gets the bare row back")
    func goneEverywhere() throws {
        let model = try makeModel(shared: true)
        try removeBareThenAdd(model, .everywhere)
        model.updateActiveProfile()
        let apps = model.encodedReach?.appRules
        for name in ["Work", "Home"] {
            #expect(apps?.resolved(for: name)[app] == nil, "\(name)")
        }
        #expect(model.core.guiConfigStore.load()?.appRules[app] == nil)
    }
}
