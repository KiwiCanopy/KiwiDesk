import Foundation
import Testing

@testable import KiwiDeskCore

/// The titled Space rules' store (#3341): its own `titled_app_rules`
/// key in `gui.json` and a profile, a fragment's case kept on every
/// path — the verbs, a keep, a profile override, the rename walk and
/// `init.lua`.
@Suite("Titled app rule store (#3341)", .serialized)
@MainActor
struct TitledAppRuleStoreTests {
    private let rule = "com.brave.browser:Work/~Profile"

    private func run(
        _ core: KiwiCore,
        _ command: String,
        _ args: [String]
    ) -> CommandResponse {
        core.execute(command, args: args.map(JSONValue.string))
    }

    @Test("set_space with a title sets a titled rule, not the bare one")
    func verbsKeepTheirFamily() throws {
        let core = try KeepFixture.core()
        #expect(
            run(
                core,
                "app_rule.set_space",
                ["Com.Brave.Browser", "1", "Work/~Profile"]
            ).isSuccess
        )
        #expect(core.state.titledAppRules.rawRules == [rule: "1"])
        #expect(core.state.appRules["com.brave.browser"] == nil)
        #expect(
            run(core, "app_rule.remove_space", ["com.brave.browser"])
                .isSuccess == false
        )
        #expect(
            run(
                core,
                "app_rule.remove_space",
                ["com.brave.browser", "work/~profile"]
            ).isSuccess == false
        )
        #expect(
            run(
                core,
                "app_rule.remove_space",
                ["com.brave.browser", "Work/~Profile"]
            ).isSuccess
        )
        #expect(core.state.titledAppRules.rawRules.isEmpty)
    }

    @Test("a keep stores the rule whole, slash and tilde included")
    func keepEscapesThePath() throws {
        let core = try KeepFixture.core()
        let set = KeepFixture.report(
            core,
            "app_rule.set_space",
            [
                .string("com.brave.browser"), .string("1"),
                .string("Work/~Profile"),
            ]
        )
        let ids = (set.changes?.touched ?? []).map(\.id)
        #expect(
            ids == ["/titled_app_rules/com.brave.browser:Work~1~0Profile"]
        )
        _ = core.execute(
            KiwiCore.keepSettingsCommand,
            args: ids.map(JSONValue.string)
        )
        #expect(core.guiConfigStore.load()?.titledAppRules == [rule: "1"])
        #expect(core.state.titledAppRules.rawRules == [rule: "1"])
    }

    @Test("a profile override keeps a fragment's case")
    func overrideKeepsCase() throws {
        let base: [String: SpaceID] = ["com.x:Work": "1"]
        let edited: [String: SpaceID] = [
            "com.x:Work": "2", "com.x:work": "3",
        ]
        let over = try #require(
            AppRuleOverride.diff(
                base: base,
                edited: edited,
                normalizing: AppTitleRule.normalizedRule
            )
        )
        #expect(
            ConfigResolver.resolvedTitledAppRules(
                base: base,
                profile: over
            ) == edited
        )
        let data = try JSONEncoder().encode(
            Profile(
                name: "P",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaces: ["1"],
                spaceModes: [:],
                settings: TilingSettings(),
                titledAppRules: over
            )
        )
        let back = try JSONDecoder().decode(Profile.self, from: data)
        #expect(back.titledAppRules == over)
        #expect(
            String(decoding: data, as: UTF8.self)
                .contains("\"titled_app_rules\"")
        )
    }

    @Test("gui.json round-trips the store and omits it when empty")
    func sidecarRoundTrip() throws {
        var config = GuiConfig()
        let empty = String(
            decoding: try JSONEncoder().encode(config),
            as: UTF8.self
        )
        #expect(!empty.contains("titled_app_rules"))
        config.titledAppRules = [rule: "1"]
        let data = try JSONEncoder().encode(config)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.titledAppRules == [rule: "1"])
    }

    @Test("renaming a Space renames the titled rules that name it")
    func renameWalks() {
        var config = GuiConfig()
        config.spaces = ["1", "2"]
        config.titledAppRules = [rule: "1", "com.x:A": "2"]
        let renamed = config.renameSpace(from: "1", to: "web")
        #expect(renamed)
        #expect(config.titledAppRules == [rule: "web", "com.x:A": "2"])
    }

    @Test("init.lua's titled_app_rules keeps the fragment's case")
    func luaReads() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kd-titled-lua-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try """
        titled_app_rules = {
            ["Com.Brave.Browser:Work"] = "2",
        }
        """.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        #expect(
            core.state.titledAppRules.rawRules
                == ["com.brave.browser:Work": "2"]
        )
        #expect(ManagedConfig.hasForeignCode("titled_app_rules = {}"))
    }
}
