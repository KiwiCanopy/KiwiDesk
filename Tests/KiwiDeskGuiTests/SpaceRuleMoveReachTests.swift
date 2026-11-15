import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Space rule moved to a new key keeps its reach (#3341): a
/// pattern edit is the same rule to every profile it reached, never
/// a removal plus a new rule at the default reach.
@Suite("A moved Space rule keeps its reach (#3341)", .serialized)
@MainActor
struct SpaceRuleMoveReachTests {
    private let app = "com.brave.browser"

    private var work: SpaceRuleRow { SpaceRuleRow(app: app, fragment: "Work") }
    private var job: SpaceRuleRow { SpaceRuleRow(app: app, fragment: "Job") }

    /// Work loaded, Home stored; `base` the shared titled rules,
    /// `own` Work's own.
    private func makeModel(
        base: [String: SpaceID],
        own: [String: SpaceID?] = [:]
    ) throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.titledAppRules = base
        try core.guiConfigStore.save(config)
        var loaded = profile("Work")
        if !own.isEmpty { loaded.titledAppRules = AppRuleOverride(rules: own) }
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

    private func rename(_ model: SettingsModel) {
        model.moveSpaceRule(from: work, to: job) {
            SpaceRuleEdit.setFragment("Job", of: work, in: &$0)
        }
    }

    private func resolved(
        _ model: SettingsModel,
        _ profile: String
    ) -> [String: SpaceID] {
        model.encodedReach?.titledAppRules.resolved(for: profile) ?? [:]
    }

    @Test("a shared rule renamed stays shared")
    func sharedStaysShared() throws {
        let model = try makeModel(base: [work.key: "1"])
        #expect(model.titledSpaceReach(work.key)?.shared == true)
        rename(model)
        for name in ["Work", "Home"] {
            #expect(resolved(model, name) == [job.key: "1"], "\(name)")
        }
    }

    @Test("a rule of one profile renamed stays that profile's")
    func ownStaysOwn() throws {
        let model = try makeModel(base: [:], own: [work.key: "2"])
        #expect(model.titledSpaceReach(work.key)?.users == ["Work"])
        rename(model)
        #expect(resolved(model, "Work") == [job.key: "2"])
        #expect(resolved(model, "Home").isEmpty)
    }

    @Test("an edit that changes nothing records no reach")
    func unchangedRecordsNothing() throws {
        let model = try makeModel(base: [work.key: "1"])
        model.moveSpaceRule(from: work, to: work) {
            SpaceRuleEdit.setFragment("Work", of: work, in: &$0)
        }
        #expect(model.reachEdits == RuleReachEdits())
    }

    /// The move crosses stores: the reach is carried into the bare
    /// family's table, not left in the titled one.
    @Test("a titled rule of one profile turned bare stays that profile's")
    func ownStaysOwnAcrossStores() throws {
        let model = try makeModel(base: [:], own: [work.key: "2"])
        let bare = SpaceRuleRow(app: app, fragment: nil)
        model.moveSpaceRule(from: work, to: bare) {
            SpaceRuleEdit.makeBare(work, in: &$0)
        }
        let apps = model.encodedReach?.appRules
        #expect(apps?.resolved(for: "Work") == [app: "2"])
        #expect(apps?.resolved(for: "Home")[app] == nil)
        #expect(resolved(model, "Work").isEmpty)
    }
}
