import Foundation
import Testing

@testable import KiwiDeskCore

/// The `app_rule.*` verbs (#1685 ▸ Ruling 6c): live only, and every
/// change reported with where a keep would write it.
@Suite("App rule commands", .serialized)
@MainActor
struct AppRuleCommandsTests {
    private func run(
        _ core: KiwiCore,
        _ command: String,
        _ args: [String] = []
    ) -> CommandResponse {
        core.execute(command, args: args.map(JSONValue.string))
    }

    @Test("a set changes the live rule and writes no file")
    func setIsLiveOnly() throws {
        let core = try KeepFixture.core()
        let before = core.guiConfigStore.load()?.appRules
        #expect(
            run(core, "app_rule.set_space", ["Com.Spotify.Client", "1"])
                .isSuccess
        )
        #expect(core.state.appRules["com.spotify.client"] == "1")
        #expect(core.guiConfigStore.load()?.appRules == before)
        #expect(try core.profiles.read(name: "Work").appRules == nil)
        #expect(
            run(core, "app_rule.remove_space", ["com.spotify.client"])
                .isSuccess
        )
        #expect(core.state.appRules["com.spotify.client"] == nil)
    }

    @Test("a float rule keeps its title's case and comes off again")
    func floatRoundTrip() throws {
        let core = try KeepFixture.core()
        #expect(
            run(core, "app_rule.set_float", ["Com.Apple.Finder", "Get Info"])
                .isSuccess
        )
        let rule = "com.apple.finder:Get Info"
        #expect(core.eventLoop.floatRules.rawRules.contains(rule))
        #expect(
            core.eventLoop.floatRules.matches(
                bundleID: "com.apple.finder",
                title: "Get Info — Disk"
            )
        )
        #expect(
            run(
                core,
                "app_rule.remove_float",
                ["com.apple.finder", "Get Info"]
            )
            .isSuccess
        )
        #expect(!core.eventLoop.floatRules.rawRules.contains(rule))
    }

    @Test("a bad app, an unknown Space or a missing rule is refused")
    func refusals() throws {
        let core = try KeepFixture.core()
        #expect(!run(core, "app_rule.set_space", ["", "1"]).isSuccess)
        #expect(!run(core, "app_rule.set_space", ["a:b", "1"]).isSuccess)
        let unknown = run(core, "app_rule.set_space", ["com.x", "9"])
        #expect(unknown.error == "unknown space: 9")
        #expect(!run(core, "app_rule.remove_space", ["com.x"]).isSuccess)
        #expect(!run(core, "app_rule.remove_float", ["com.x"]).isSuccess)
        #expect(core.state.appRules["com.x"] == nil)
    }

    @Test("list reports the live rules and their owner")
    func listsLiveRules() throws {
        let core = try KeepFixture.core()
        _ = run(core, "app_rule.set_space", ["com.x", "1"])
        _ = run(core, "app_rule.set_float", ["com.y"])
        guard case .object(let fields)? = run(core, "app_rule.list").data
        else {
            Issue.record("no list")
            return
        }
        #expect(fields["spaces"] == .object(["com.x": .string("1")]))
        guard case .array(let floats)? = fields["floats"] else {
            Issue.record("no floats")
            return
        }
        #expect(floats.contains(.string("com.y")))
        #expect(fields["owner"] == .string("gui"))
        #expect(fields["profile"] == .string("Work"))
    }

    @Test("a new rule reports the shared rules as its owner")
    func newRuleIsShared() throws {
        let core = try KeepFixture.core()
        let set = KeepFixture.report(
            core,
            "app_rule.set_space",
            [.string("com.x"), .string("1")]
        )
        let leaf = KeepFixture.leaf(set, "/app_rules/")
        #expect(leaf?.id == "/app_rules/com.x")
        #expect(leaf?.owner == .sharedRules)
        let float = KeepFixture.report(
            core,
            "app_rule.set_float",
            [.string("com.x"), .string("A/B")]
        )
        #expect(
            KeepFixture.leaf(float, "/float_rules/")?.id
                == "/float_rules/com.x:A~1B"
        )
    }

    @Test("a rule the profile holds reports the profile")
    func ownRuleIsTheProfiles() throws {
        let core = try KeepFixture.core()
        var odd = KeepFixture.profile("Odd")
        odd.appRules = AppRuleOverride(rules: ["com.x": "1"])
        try core.profiles.save(odd)
        KeepFixture.load("Odd", core)
        let set = KeepFixture.report(
            core,
            "app_rule.remove_space",
            [.string("com.x")]
        )
        #expect(KeepFixture.leaf(set, "/app_rules/")?.owner == .profile)
    }

    @Test("a Space the profile does not declare cannot be kept")
    func temporarySpaceIsRefused() throws {
        let core = try KeepFixture.core()
        #expect(run(core, "create_space", ["2"]).isSuccess)
        let set = KeepFixture.report(
            core,
            "app_rule.set_space",
            [.string("com.x"), .string("2")]
        )
        let leaf = KeepFixture.leaf(set, "/app_rules/")
        #expect(leaf?.notKeepable == .temporarySpace)
    }

    @Test("an init.lua config owns its rules")
    func luaOwnsRules() throws {
        let core = try KeepFixture.core(gui: false)
        let set = KeepFixture.report(
            core,
            "app_rule.set_float",
            [.string("com.x")]
        )
        let leaf = KeepFixture.leaf(set, "/float_rules/")
        #expect(leaf?.notKeepable == .luaOwned)
    }
}
