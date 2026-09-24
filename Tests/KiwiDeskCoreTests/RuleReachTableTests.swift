import Foundation
import Testing

@testable import KiwiDeskCore

/// Who a rule reaches, and how a checklist change is written back
/// (#1393): the table over the shared base and each profile's
/// sparse entries.
@Suite("Rule reach table (#1393)")
struct RuleReachTableTests {
    private let names = ["Work", "Home", "Travel"]

    /// Slack shared; Spotify Work-only; Mail shared with Travel left
    /// out; Figma shared with Home's own Space.
    private var table: RuleReachTable<SpaceID> {
        .appRules(
            base: ["slack": 2, "mail": 1, "figma": 4],
            overrides: [
                ("Work", AppRuleOverride(rules: ["spotify": 3])),
                ("Home", AppRuleOverride(rules: ["figma": 2])),
                ("Travel", AppRuleOverride(rules: ["mail": nil])),
            ]
        )
    }

    @Test("A followed base rule reads as shared; an own one as a list")
    func derivesReach() {
        let t = table
        #expect(t.reach(of: "slack", editing: "Work") == .shared(joining: []))
        #expect(t.reach(of: "spotify", editing: "Work") == .listed(["Work"]))
        #expect(t.reach(of: "figma", editing: "Home") == .listed(["Home"]))
        #expect(t.differing("figma", editing: "Work") == ["Home"])
        #expect(t.differing("mail", editing: "Work").isEmpty)
    }

    @Test("An entry equal to the base still follows it")
    func redundantEntryFollows() {
        let t = RuleReachTable<SpaceID>.appRules(
            base: ["slack": 2],
            overrides: [("Work", AppRuleOverride(rules: ["slack": 2]))]
        )
        #expect(t.reach(of: "slack", editing: "Work").isShared)
    }

    @Test("Unticking All turns the followers into a list, base gone")
    func sharedToList() {
        var t = table
        t.apply(
            "mail",
            value: 1,
            reach: .listed(["Work", "Home"]),
            editing: "Work"
        )
        #expect(t.base["mail"] == nil)
        #expect(t.resolved("mail", for: "Work") == 1)
        #expect(t.resolved("mail", for: "Home") == 1)
        // Travel's left-out mark had nothing left to leave out.
        #expect(t.entries["Travel"]?["mail"] == nil)
        #expect(t.resolved("mail", for: "Travel") == nil)
    }

    @Test("Ticking a profile with its own value under All drops it")
    func sharedJoinsOwnRule() {
        var t = table
        t.apply(
            "figma",
            value: 4,
            reach: .shared(joining: ["Home"]),
            editing: "Work"
        )
        #expect(t.resolved("figma", for: "Home") == 4)
        #expect(t.entries["Home"]?["figma"] == nil)
        #expect(t.touched["Work"] == nil)
    }

    @Test("A shared row's new value moves every follower, not the own")
    func sharedValueMovesFollowers() {
        var t = table
        t.apply(
            "figma",
            value: 5,
            reach: .shared(joining: []),
            editing: "Work"
        )
        #expect(t.base["figma"] == 5)
        #expect(t.resolved("figma", for: "Travel") == 5)
        #expect(t.resolved("figma", for: "Home") == 2)
    }

    @Test("A list over another's shared rule keeps that base")
    func listKeepsForeignBase() {
        var t = table
        // Home's page: Figma is Home's own Space 2; tick Work.
        t.apply(
            "figma",
            value: 2,
            reach: .listed(["Home", "Work"]),
            editing: "Home"
        )
        #expect(t.base["figma"] == 4)
        #expect(t.resolved("figma", for: "Work") == 2)
        #expect(t.resolved("figma", for: "Travel") == 4)
    }

    @Test("Unticking a list member drops its entry")
    func untickMember() {
        var t = RuleReachTable<SpaceID>.appRules(
            base: [:],
            overrides: [
                ("Work", AppRuleOverride(rules: ["mail": 1])),
                ("Home", AppRuleOverride(rules: ["mail": 1])),
            ]
        )
        t.apply(
            "mail",
            value: 1,
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(t.resolved("mail", for: "Home") == nil)
        #expect(t.touched["Home"] == ["mail"])
    }

    @Test("Remove here leaves out a shared rule, drops an own one")
    func removeHere() {
        var t = table
        t.apply(
            "slack",
            value: nil,
            reach: .shared(joining: []),
            removal: .here,
            editing: "Work"
        )
        #expect(t.entries["Work"]?["slack"] == .some(nil))
        #expect(t.resolved("slack", for: "Home") == 2)
        t.apply(
            "spotify",
            value: nil,
            reach: .listed(["Work"]),
            removal: .here,
            editing: "Work"
        )
        #expect(t.entries["Work"]?["spotify"] == nil)
    }

    @Test("Remove everywhere spares another value and its left-out mark")
    func removeEverywhere() {
        var t = RuleReachTable<SpaceID>.appRules(
            base: ["figma": 4],
            overrides: [
                ("Work", AppRuleOverride()),
                ("Home", AppRuleOverride(rules: ["figma": 2])),
                ("Travel", AppRuleOverride(rules: ["figma": nil])),
            ]
        )
        t.apply(
            "figma",
            value: nil,
            reach: .listed(["Home"]),
            removal: .everywhere,
            editing: "Home"
        )
        #expect(t.base["figma"] == 4)
        #expect(t.resolved("figma", for: "Home") == nil)
        #expect(t.resolved("figma", for: "Work") == 4)
        // Dropping Travel's mark would hand it the shared rule.
        #expect(t.resolved("figma", for: "Travel") == nil)
    }

    @Test("A change touches only its own key")
    func untouchedStaysAsStored() {
        var t = table
        t.apply(
            "spotify",
            value: 6,
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(t.touched == ["Work": ["spotify"]])
        #expect(t.baseTouched.isEmpty)
        #expect(
            t.appRuleOverride(for: "Home")
                == AppRuleOverride(rules: ["figma": 2])
        )
    }

    // MARK: - Float family

    /// Home floats only Zoom's Meeting windows, not all of Zoom's.
    private var homeZoom: RuleListOverride {
        var rules: [String: Bool?] = ["zoom:Meeting": true]
        rules.updateValue(nil, forKey: "zoom")
        return RuleListOverride(rules: rules)
    }

    private var floats: RuleReachTable<[String]> {
        .floatRules(
            base: ["com.calc", "zoom"],
            overrides: [
                ("Work", nil),
                (
                    "Home",
                    homeZoom
                ),
            ]
        )
    }

    @Test("Float rules group per app, resolved per profile")
    func floatGroups() {
        let t = floats
        #expect(t.resolved("zoom", for: "Work") == ["zoom"])
        #expect(t.resolved("zoom", for: "Home") == ["zoom:Meeting"])
        #expect(t.reach(of: "com.calc", editing: "Home").isShared)
    }

    @Test("An untouched float override is returned as stored")
    func floatUntouched() {
        let original = homeZoom
        var t = floats
        t.apply(
            "com.calc",
            value: ["com.calc"],
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(
            t.floatRuleOverride(for: "Home", original: original)
                == original
        )
    }

    @Test("A moved float base re-encodes an own rule to keep it")
    func floatBaseMoveKeepsOwn() {
        let original = homeZoom
        var t = floats
        t.apply(
            "zoom",
            value: ["zoom", "zoom:Share"],
            reach: .shared(joining: []),
            editing: "Work"
        )
        let encoded = t.floatRuleOverride(for: "Home", original: original)
        let base = t.floatRuleBase(original: ["com.calc", "zoom"])
        #expect(base == ["com.calc", "zoom", "zoom:Share"])
        let resolved = encoded?.resolved(
            onto: base,
            normalizing: FloatRules.normalizedRule
        ).sorted()
        #expect(resolved == ["com.calc", "zoom:Meeting"])
    }
}

/// The door writes each reached profile, then the base.
@Suite("Rule reach save (#1393)", .serialized)
@MainActor
struct RuleReachSaveTests {
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-reach-\(UUID().uuidString)")
        )
        var config = GuiConfig()
        config.appRules = ["mail": SpaceID(1)]
        try core.guiConfigStore.save(config)
        for name in ["Home", "Work"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["\(name):1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            )
        }
        return core
    }

    @Test("Unticking Home writes Work's file and drops the base")
    func unticksHome() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.appRules.apply(
            "mail",
            value: 1,
            reach: .listed(["Work"]),
            editing: "Work"
        )
        try core.saveRuleReach(snapshot)
        #expect(core.guiConfigStore.load()?.appRules["mail"] == nil)
        let work = try core.profiles.read(name: "Work")
        #expect(work.appRules == AppRuleOverride(rules: ["mail": 1]))
        let home = try core.profiles.read(name: "Home")
        #expect(home.appRules == nil)
    }

    @Test("An unedited snapshot writes nothing")
    func uneditedWritesNothing() throws {
        let core = try makeCore()
        let before = try Data(
            contentsOf: core.profiles.fileURL(name: "Home")
        )
        let snapshot = try #require(core.ruleReachSnapshot())
        try core.saveRuleReach(snapshot)
        let after = try Data(contentsOf: core.profiles.fileURL(name: "Home"))
        #expect(before == after)
    }
}
