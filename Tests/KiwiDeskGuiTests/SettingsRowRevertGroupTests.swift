import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The ↺'s that take state written together back together (#792):
/// a Space through the Space doors, a bar's edge with its
/// per-screen map, a titled rule with its app's reach — each
/// landing exactly on the baseline.
@MainActor
@Suite("Settings row revert groups (#792)")
struct SettingsRowRevertGroupTests {
    private func model(
        clean: GuiConfig,
        draft: GuiConfig
    ) -> SettingsModel {
        let model = makeTestModel()
        model.cleanConfig = clean
        model.config = draft
        return model
    }

    private func censusRow(
        _ key: SettingKey,
        _ instance: String?
    ) -> SettingsDiffRow {
        var row = SettingsDiffRow.note(
            key,
            instance: instance,
            label: "",
            note: ""
        )
        row.revert = .census
        return row
    }

    private func spaced() -> GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID("mail"), SpaceID("code")]
        config.spaceModes[SpaceID("mail")] = .grid
        var bsp = BspOverride()
        bsp.splitRatioH = 0.6
        config.settings.bsp.override[SpaceID("mail")] = bsp
        config.appRules["com.apple.mail"] = SpaceID("mail")
        return config
    }

    @Test("a renamed Space takes its old name and what it owns back")
    func renameGoesBack() {
        let clean = spaced()
        var draft = clean
        let renamed = draft.renameSpace(
            from: SpaceID("mail"),
            to: SpaceID("post")
        )
        #expect(renamed)
        let model = model(clean: clean, draft: draft)
        model.revert(censusRow(.spaces(.spacesName), "post"))
        #expect(model.config == clean)
    }

    @Test("a deleted Space returns as the baseline held it")
    func deletedSpaceReturns() {
        let clean = spaced()
        var draft = clean
        draft.removeSpace(SpaceID("mail"))
        let model = model(clean: clean, draft: draft)
        model.revert(censusRow(.spaces(.spaceList), "mail"))
        #expect(model.config == clean)
    }

    @Test("an added Space leaves with what was filed under it")
    func addedSpaceLeaves() {
        let clean = spaced()
        var draft = clean
        draft.spaces.append(SpaceID("new"))
        draft.spaceModes[SpaceID("new")] = .monocle
        let model = model(clean: clean, draft: draft)
        model.revert(censusRow(.spaces(.spaceList), "new"))
        #expect(model.config == clean)
    }

    /// The Position master clears every screen's own edge through
    /// the doors; its ↺ puts both bars' pairs back.
    @Test("the edge master puts both edges and their screens back")
    func edgeMasterRestoresScreens() {
        var clean = GuiConfig()
        clean.settings.spaceBarStyle.edge = .top
        clean.settings.spaceBarStyle.edgeOverride["S:1x1"] = .bottom
        var draft = clean
        draft.settings.spaceBarStyle.edge = .bottom
        draft.settings.spaceBarStyle.edgeOverride = [:]
        draft.settings.appBarStyle.edge = .bottom
        let model = model(clean: clean, draft: draft)
        model.revert(censusRow(.kiwishelf(.edge), nil))
        #expect(model.config == clean)
    }

    /// A reach row's app is its titled rules' app: the ↺ swaps all
    /// of them back and settles the app's reach.
    @Test("a titled float rule's reach row takes the app's rules back")
    func titledFloatReachReverts() {
        var clean = GuiConfig()
        clean.floatRules = ["Info", "com.apple.finder:Get Info"]
        var draft = clean
        draft.floatRules = ["Info", "com.apple.finder:Copy"]
        let model = model(clean: clean, draft: draft)
        let app = RuleFamily.float.subject(ofRule: "com.apple.finder:Copy")
        model.reachEdits.reach[.float] = [app: .shared(joining: [])]
        var row = SettingsDiffRow.note(
            .appRules(.floatRules),
            instance: "reach.new.\(app)",
            label: "",
            note: ""
        )
        row.revert = .ruleReach(app: app)
        model.revert(row)
        #expect(model.config.floatRules == clean.floatRules)
        #expect(model.reachEdits.reach[.float]?[app] == nil)
    }

    /// A titled rule's list row settles its app's reach once the
    /// app's rules are the baseline's.
    @Test("a titled rule's list row settles its app's reach")
    func titledListRowSettlesReach() {
        var clean = GuiConfig()
        clean.floatRules = ["Info"]
        var draft = clean
        draft.floatRules = ["Info", "com.apple.finder:Copy"]
        let model = model(clean: clean, draft: draft)
        let app = RuleFamily.float.subject(ofRule: "com.apple.finder:Copy")
        model.reachEdits.reach[.float] = [app: .shared(joining: [])]
        let instance = ListEntryInstance(
            added: true,
            entry: "com.apple.finder:Copy",
            occurrence: 0
        )
        model.revert(censusRow(.appRules(.floatRules), instance.spelled))
        #expect(model.config.floatRules == clean.floatRules)
        #expect(model.reachEdits.reach[.float]?[app] == nil)
    }

    /// A row's id holds when a sibling of the same list leaves, or
    /// a ↺ hands focus to an id no row carries.
    @Test("a list row's id outlives its sibling's revert")
    func listIDsAreStable() throws {
        LocalizationManager.shared.select("en")
        var clean = GuiConfig()
        clean.floatRules = []
        var draft = clean
        draft.floatRules = ["A", "B"]
        let model = model(clean: clean, draft: draft)
        let before = SettingsDiffRowSource.rows(for: model)
        let first = try #require(before.first { $0.instance == "+A#0" })
        let second = try #require(before.first { $0.instance == "+B#0" })
        model.revert(first)
        let after = SettingsDiffRowSource.rows(for: model)
        #expect(after.map(\.id) == [second.id])
    }
}
