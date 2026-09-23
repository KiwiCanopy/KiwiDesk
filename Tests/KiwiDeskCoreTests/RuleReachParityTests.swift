import Foundation
import Testing

@testable import KiwiDeskCore

/// The table answers what the engine does, and a re-encode keeps
/// it (#1393): the reviewers' cases beside the adapters' parity
/// with the override primitives that own resolution.
@Suite("Rule reach parity and edge cases (#1393)")
struct RuleReachParityTests {
    private let appBase: [String: SpaceID] = ["mail": 1, "figma": 4]
    private let appOverrides: [(String, AppRuleOverride?)] = [
        ("Work", AppRuleOverride(rules: ["spotify": 3])),
        ("Home", AppRuleOverride(rules: ["figma": 2, "mail": nil])),
        ("Travel", nil),
    ]

    @Test("The app table resolves as AppRuleOverride does")
    func appParity() {
        let table = RuleReachTable<SpaceID>.appRules(
            base: appBase,
            overrides: appOverrides
        )
        for (name, override) in appOverrides {
            let engine =
                override?.resolved(onto: appBase)
                ?? AppRuleOverride.normalized(appBase)
            #expect(table.resolved(for: name) == engine, "\(name)")
        }
    }

    @Test("A re-encoded float table resolves as the list primitive")
    func floatParityAfterEncode() {
        var rules: [String: Bool?] = ["zoom:Meeting": true]
        rules.updateValue(nil, forKey: "zoom")
        let home = RuleListOverride(rules: rules)
        var table = RuleReachTable<[String]>.floatRules(
            base: ["zoom", "com.calc"],
            overrides: [("Work", nil), ("Home", home)]
        )
        table.apply(
            "com.calc",
            value: ["com.calc"],
            reach: .listed(["Work"]),
            editing: "Work"
        )
        let base = table.floatRuleBase(original: ["zoom", "com.calc"])
        for (name, original) in [("Work", nil), ("Home", home)] {
            let encoded = table.floatRuleOverride(
                for: name,
                original: original
            )
            let engine =
                encoded?.resolved(
                    onto: base,
                    normalizing: FloatRules.normalizedRule
                ) ?? base
            let expected = table.resolved(for: name).values
                .flatMap { $0 }
            #expect(Set(engine) == Set(expected), "\(name)")
        }
    }

    @Test("A listed rule from a left-out page keeps another's mark")
    func listedKeepsOthersLeftOut() {
        var table = RuleReachTable<SpaceID>.appRules(
            base: ["mail": 1],
            overrides: [
                ("Home", AppRuleOverride(rules: ["mail": nil])),
                ("Travel", AppRuleOverride(rules: ["mail": nil])),
            ]
        )
        table.apply(
            "mail",
            value: 3,
            reach: .listed(["Travel"]),
            editing: "Travel"
        )
        #expect(table.resolved("mail", for: "Travel") == 3)
        #expect(table.resolved("mail", for: "Home") == nil)
        #expect(table.leftOut("mail") == ["Home"])
    }

    @Test("A shared move takes an entry equal to the old base along")
    func sharedMoveDropsRedundant() {
        var table = RuleReachTable<SpaceID>.appRules(
            base: ["mail": 1],
            overrides: [
                ("Work", nil),
                ("Home", AppRuleOverride(rules: ["mail": 1])),
            ]
        )
        table.apply(
            "mail",
            value: 2,
            reach: .shared(joining: []),
            editing: "Work"
        )
        #expect(table.resolved("mail", for: "Home") == 2)
    }

    @Test("An untouched Space rule keeps its stored spelling")
    func appBaseKeepsSpelling() {
        let original: [String: SpaceID] = ["com.Apple.Mail": 1, "zoom": 2]
        var table = RuleReachTable<SpaceID>.appRules(
            base: original,
            overrides: [("Work", nil)]
        )
        #expect(table.appRuleBase(original: original) == original)
        table.apply(
            "zoom",
            value: 3,
            reach: .shared(joining: []),
            editing: "Work"
        )
        #expect(
            table.appRuleBase(original: original)
                == ["com.Apple.Mail": 1, "zoom": 3]
        )
    }
}

/// A stored Save leaves the rule families to the table (#1393).
@Suite("overwriteProfile writingRules (#1393)", .serialized)
@MainActor
struct OverwriteProfileRulesTests {
    @Test("writingRules false keeps the stored rule overrides")
    func keepsStoredRules() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-owr-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        let own = AppRuleOverride(rules: ["mail": 2])
        try core.profiles.write(
            Profile(
                name: "Home",
                monitorSets: [MonitorSet(monitors: ["H:1x1"])],
                spaceModes: [:],
                settings: TilingSettings(),
                appRules: own
            )
        )
        var config = try core.loadGuiConfig(editing: "Home")
        config.appRules = ["mail": 3]
        try core.overwriteProfile(
            named: "Home",
            with: config,
            writingRules: false
        )
        #expect(try core.profiles.read(name: "Home").appRules == own)
    }
}
