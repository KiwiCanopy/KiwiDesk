import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Two checklist rulings (owner, 2026-09-25, #1393): a profile
/// ticked under All profiles stays untickable until the Save, and
/// only a shared row warns that a profile differs.
@Suite("Rule reach join undo and warning (#1393)", .serialized)
@MainActor
struct RuleReachJoinUndoTests {
    /// gui.json opens Mail in Space 1; Work (loaded) follows it,
    /// Home and Travel keep their own Space 2.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.appRules = ["mail": SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        var home = profile("Home")
        home.appRules = AppRuleOverride(rules: ["mail": SpaceID("2")])
        try core.profiles.write(home)
        var travel = profile("Travel")
        travel.appRules = AppRuleOverride(rules: ["mail": SpaceID("2")])
        try core.profiles.write(travel)
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

    @Test("a tick under All profiles can be taken back before the Save")
    func joinIsUndoable() throws {
        let model = try makeModel()
        let before = try #require(model.spaceReach("mail"))
        #expect(before.shared && before.own["Home"] != nil)

        model.setProfile(.space, "mail", "Home", true)
        let joined = try #require(model.spaceReach("mail"))
        #expect(joined.users.contains("Home"))
        #expect(!joined.follows("Home"))

        model.setProfile(.space, "mail", "Home", false)
        let undone = try #require(model.spaceReach("mail"))
        #expect(undone.own["Home"] != nil)
        #expect(!model.isDirty)
        // No pick is left behind to grey Save as new profile.
        #expect(!model.copyWaitsOnReach)
    }

    @Test("after the Save a joined profile follows, locked")
    func joinLocksAfterSave() throws {
        let model = try makeModel()
        model.setProfile(.space, "mail", "Home", true)
        model.updateActiveProfile()

        #expect(try model.core.profiles.read(name: "Home").appRules == nil)
        let saved = try #require(model.spaceReach("mail"))
        #expect(saved.follows("Home"))
    }

    @Test("only a shared row warns that a profile differs")
    func warningOnlyOnShared() throws {
        let model = try makeModel()
        let shared = try #require(model.spaceReach("mail"))
        #expect(RuleReachWords.differing(shared) != nil)

        // On Home's page the rule is Home's own list.
        model.selectEditTarget("Home")
        let listed = try #require(model.spaceReach("mail"))
        #expect(!listed.shared)
        #expect(RuleReachWords.differing(listed) == nil)
    }

    @Test("the replace note shows once, while a profile keeps its own")
    func replaceNoteOnce() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = try makeModel()
        let note =
            "Ticking a profile with its own rule replaces it with the "
            + "shared one."
        let before = try #require(model.spaceReach("mail"))
        #expect(RuleReachWords.notes(before).filter { $0 == note }.count == 1)

        // Still one note while Travel keeps its own; none once both
        // have joined.
        model.setProfile(.space, "mail", "Home", true)
        let one = try #require(model.spaceReach("mail"))
        #expect(RuleReachWords.notes(one).filter { $0 == note }.count == 1)
        model.setProfile(.space, "mail", "Travel", true)
        let joined = try #require(model.spaceReach("mail"))
        #expect(!RuleReachWords.notes(joined).contains(note))
    }
}
