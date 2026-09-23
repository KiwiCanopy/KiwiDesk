import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The App Rules checklist end to end (#1393): the draft's ticks
/// reach the files a Save writes, from the loaded profile's page
/// and from a stored one's.
@Suite("Rule reach, draft to files (#1393)", .serialized)
@MainActor
struct RuleReachModelTests {
    /// gui.json opens Mail in Space 1; Work is loaded, Home stored.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.appRules = ["mail": SpaceID("1")]
        try core.guiConfigStore.save(config)
        // `save` adopts, so Work is the loaded profile.
        try core.profiles.save(profile("Work"))
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

    private func appRules(_ model: SettingsModel, _ name: String) throws
        -> AppRuleOverride?
    {
        try model.core.profiles.read(name: name).appRules
    }

    @Test("Unticking Home on Work's page reaches Home's file")
    func untickHome() throws {
        let model = try makeModel()
        #expect(model.reachProfile == "Work")
        let before = try #require(model.spaceReach("mail"))
        #expect(before.shared && before.users.contains("Home"))

        model.setAllProfiles(.space, "mail", false)
        model.setProfile(.space, "mail", "Home", false)

        #expect(model.isDirty)
        #expect(model.reachDiffRows().contains { $0.label.contains("Home") })
        model.updateActiveProfile()

        #expect(model.core.guiConfigStore.load()?.appRules["mail"] == nil)
        #expect(
            try appRules(model, "Work")
                == AppRuleOverride(rules: ["mail": SpaceID("1")])
        )
        #expect(try appRules(model, "Home") == nil)
        #expect(!model.isDirty)
    }

    @Test("A shared rule edited on a stored page moves the base")
    func storedSharedEditMovesBase() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        #expect(model.editingProfile == "Home")

        model.config.appRules["mail"] = SpaceID("2")
        model.saveEditedProfile()

        // The row showed All profiles, so the edit is the shared
        // rule's — never a silent fork into Home's file.
        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"]
                == SpaceID("2")
        )
        #expect(try appRules(model, "Home") == nil)
    }

    @Test("A new rule on a stored page starts at that profile only")
    func storedNewRuleIsOwn() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")

        model.config.appRules["notes"] = SpaceID("2")
        model.saveEditedProfile()

        #expect(model.core.guiConfigStore.load()?.appRules["notes"] == nil)
        #expect(
            try appRules(model, "Home")
                == AppRuleOverride(rules: ["notes": SpaceID("2")])
        )
    }

    @Test("Remove here leaves the shared rule out of Work alone")
    func removeHere() throws {
        let model = try makeModel()

        model.recordRemoval(.space, "mail", .here)
        model.config.appRules["mail"] = nil
        model.updateActiveProfile()

        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"]
                == SpaceID("1")
        )
        #expect(
            try appRules(model, "Work")
                == AppRuleOverride(rules: ["mail": nil])
        )
        #expect(try appRules(model, "Home") == nil)
    }

    @Test("Ticking Home under All profiles drops its own Space")
    func joinOwnRule() throws {
        let model = try makeModel()
        var home = profile("Home")
        home.appRules = AppRuleOverride(rules: ["mail": SpaceID("2")])
        try model.core.profiles.write(home)
        model.reload()
        let row = try #require(model.spaceReach("mail"))
        #expect(row.own["Home"] == "2")
        #expect(!row.users.contains("Home"))

        model.setProfile(.space, "mail", "Home", true)
        model.updateActiveProfile()

        #expect(try appRules(model, "Home") == nil)
    }
}
