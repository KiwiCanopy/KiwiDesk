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

    /// A rename books as the list's add and remove: their two ↺'s
    /// take the new Space out and the old one back as it was, what
    /// the rename moved under the new name included.
    @Test("a rename's two rows take the old Space back")
    func renameGoesBack() throws {
        LocalizationManager.shared.select("en")
        var clean = spaced()
        clean.appRules = [:]
        var draft = clean
        let renamed = draft.renameSpace(
            from: SpaceID("mail"),
            to: SpaceID("post")
        )
        #expect(renamed)
        let model = model(clean: clean, draft: draft)
        let rows = SettingsDiffRowSource.rows(for: model)
        #expect(rows.contains { $0.key == .spaces(.spaceList) })
        for _ in 0..<10 {
            guard let row = SettingsDiffRowSource.rows(for: model).first
            else { break }
            model.revert(row)
        }
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

    /// A Space deleted beside one added keeps the count, yet the
    /// added one's row is no rename: its ↺ takes that Space alone,
    /// and what the user pointed at it stays theirs.
    @Test("an added Space's ↺ never renames the one deleted beside it")
    func addBesideDeleteIsNoRename() {
        let clean = spaced()
        var draft = clean
        draft.removeSpace(SpaceID("code"))
        draft.spaces.append(SpaceID("new"))
        draft.appRules["com.apple.Notes"] = SpaceID("new")
        let model = model(clean: clean, draft: draft)
        model.revert(censusRow(.spaces(.spaceList), "new"))
        #expect(model.config.spaces == [SpaceID("mail")])
        #expect(model.config.appRules["com.apple.Notes"] == SpaceID("new"))
    }

    /// Only the shortcut layers' ↺ takes a group the row does not
    /// name, so only it asks first (owner, 2026-10-19).
    @Test("only a shortcut row's ↺ asks before reverting")
    func onlyShortcutsAsk() {
        let model = makeTestModel()
        #expect(model.revertTakesGroup(censusRow(.shortcuts(.layers), nil)))
        #expect(
            model.revertTakesGroup(censusRow(.shortcuts(.layersIcon), nil))
        )
        #expect(
            !model.revertTakesGroup(censusRow(.borders(.borderWidth), nil))
        )
        #expect(
            !model.revertTakesGroup(censusRow(.spaces(.spaceList), "1"))
        )
        let groups = SettingsRevertRegister.writers
            .filter { $0.value.takesGroup }.keys
        #expect(
            Set(groups) == [
                .shortcuts(.layers), .shortcuts(.layersIcon),
                .shortcuts(.shortcutBase),
            ]
        )
    }

    /// The ↺ and the row menu both go through the door that asks;
    /// only that door and the confirmation revert.
    @Test("both ways to a ↺ go through the question")
    func revertsAskThroughOneDoor() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsDiffRowsView.swift"
            )
        let text = try SourceScan.strippedSource(at: url)
        let count = { (needle: String) in
            text.components(separatedBy: needle).count - 1
        }
        #expect(count("requestRevert(row, among: shown, with: revert)") == 2)
        // The door's own branch and the confirmation.
        #expect(count("revertRow(") == 3)
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
