import Foundation
import Testing

@testable import KiwiDeskCore

/// `keep_settings` for the app rules (#1685 ▸ Ruling 6c): a new
/// rule lands in the shared base, a profile's own rule in its file,
/// and nothing live moves.
@Suite("App rule keep", .serialized)
@MainActor
struct AppRuleKeepTests {
    private func ids(_ response: CommandResponse) -> [String] {
        (response.changes?.touched ?? []).map(\.id)
    }

    private func keep(_ core: KiwiCore, _ ids: [String]) -> CommandResponse {
        core.execute(
            KiwiCore.keepSettingsCommand,
            args: ids.map(JSONValue.string)
        )
    }

    private func kept(_ response: CommandResponse) -> [String] {
        guard case .object(let fields)? = response.data,
            case .array(let items)? = fields["kept"]
        else { return [] }
        return items.compactMap { item in
            guard case .object(let leaf) = item else { return nil }
            return leaf["id"]?.stringValue
        }
    }

    @Test("a new rule lands in the shared base and names followers")
    func newRuleLandsShared() throws {
        let core = try KeepFixture.core()
        var told = 0
        core.onRulesKept = { told += 1 }
        let set = KeepFixture.report(
            core,
            "app_rule.set_space",
            [.string("com.x"), .string("1")]
        )
        let response = keep(core, ids(set))
        #expect(kept(response) == ["/app_rules/com.x"])
        #expect(core.guiConfigStore.load()?.appRules["com.x"] == "1")
        #expect(try core.profiles.read(name: "Work").appRules == nil)
        #expect(told == 1)
        guard case .object(let fields)? = response.data else { return }
        #expect(fields["rule_profiles"] == .array([.string("Work")]))
    }

    @Test("a profile's own rule is kept in its file")
    func ownRuleLandsInTheProfile() throws {
        let core = try KeepFixture.core()
        var odd = KeepFixture.profile("Odd")
        odd.appRules = AppRuleOverride(rules: ["com.x": "1"])
        try core.profiles.save(odd)
        KeepFixture.load("Odd", core)
        let removed = KeepFixture.report(
            core,
            "app_rule.remove_space",
            [.string("com.x")]
        )
        #expect(kept(keep(core, ids(removed))) == ["/app_rules/com.x"])
        let stored = try core.profiles.read(name: "Odd")
        #expect(stored.appRules?.normalizedRules["com.x"] == nil)
        #expect(core.guiConfigStore.load()?.appRules["com.x"] == nil)
    }

    @Test("a partial keep leaves the other change live and unkept")
    func partialKeepMovesNothingLive() throws {
        let core = try KeepFixture.core()
        let first = KeepFixture.report(
            core,
            "app_rule.set_space",
            [.string("com.x"), .string("1")]
        )
        _ = KeepFixture.report(core, "app_rule.set_float", [.string("com.y")])
        _ = keep(core, ids(first))
        #expect(core.eventLoop.floatRules.rawRules.contains("com.y"))
        let watched = core.answer(
            .reporting("version", watch: ["/float_rules/com.y"])
        )
        #expect(watched.changes?.watched.first?.stored == false)
        #expect(
            core.guiConfigStore.load()?.floatRules.contains("com.y")
                == false
        )
    }

    @Test("a float rule keeps beside the app's other rules")
    func floatRuleKeeps() throws {
        let core = try KeepFixture.core()
        let set = KeepFixture.report(
            core,
            "app_rule.set_float",
            [.string("com.x"), .string("Info")]
        )
        #expect(kept(keep(core, ids(set))) == ["/float_rules/com.x:Info"])
        #expect(core.guiConfigStore.load()?.floatRules == ["com.x:Info"])
        #expect(core.eventLoop.floatRules.rawRules.contains("com.x:Info"))
    }

    @Test("removing a shared rule takes it from the base")
    func sharedRemovalLeavesTheBase() throws {
        let core = try KeepFixture.core()
        var base = try #require(core.guiConfigStore.load())
        base.appRules = ["com.x": "1"]
        try core.guiConfigStore.save(base)
        KeepFixture.load("Work", core)
        #expect(core.state.appRules["com.x"] == "1")
        let removed = KeepFixture.report(
            core,
            "app_rule.remove_space",
            [.string("com.x")]
        )
        #expect(
            KeepFixture.leaf(removed, "/app_rules/")?.owner == .sharedRules
        )
        #expect(kept(keep(core, ids(removed))) == ["/app_rules/com.x"])
        #expect(core.guiConfigStore.load()?.appRules["com.x"] == nil)
    }

    @Test("the automatic-float switch keeps like a rule")
    func floatAutomaticallyKeeps() throws {
        let core = try KeepFixture.core()
        let base = core.guiConfigStore.load()?.floatAutomatically
        let flipped = !(base ?? true)
        let set = KeepFixture.report(
            core,
            "set_float_automatically",
            [.bool(flipped)]
        )
        let leaf = KeepFixture.leaf(set, "/float_automatically")
        #expect(leaf?.owner == .sharedRules)
        #expect(kept(keep(core, ids(set))) == ["/float_automatically"])
        #expect(core.guiConfigStore.load()?.floatAutomatically == flipped)
    }

    /// A rule the page leaves out is a new one there: the report
    /// and the keep agree it is the shared rule, and the profile
    /// that left it out is named among those it reached.
    @Test("a left-out rule is reported and kept as shared")
    func leftOutRuleIsShared() throws {
        let core = try KeepFixture.core()
        var base = try #require(core.guiConfigStore.load())
        base.appRules = ["com.x": "1"]
        try core.guiConfigStore.save(base)
        var odd = KeepFixture.profile("Odd")
        let leftOut: [String: SpaceID?] = ["com.x": SpaceID?.none]
        odd.appRules = AppRuleOverride(rules: leftOut)
        try core.profiles.save(odd)
        KeepFixture.load("Odd", core)
        #expect(core.state.appRules["com.x"] == nil)
        let set = KeepFixture.report(
            core,
            "app_rule.set_space",
            [.string("com.x"), .string("1")]
        )
        #expect(KeepFixture.leaf(set, "/app_rules/")?.owner == .sharedRules)
        let response = keep(core, ids(set))
        #expect(kept(response) == ["/app_rules/com.x"])
        guard case .object(let fields)? = response.data else { return }
        #expect(fields["rule_profiles"] == .array([.string("Odd")]))
        #expect(
            try core.profiles.read(name: "Odd").appRules?
                .normalizedRules["com.x"] == nil
        )
    }
}
