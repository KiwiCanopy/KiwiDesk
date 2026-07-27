import Foundation
import Testing

@testable import KiwiDeskCore

/// Integration coverage for the two sparse list-rule profile
/// tiers (#287). Global ownership may come from gui.json or Lua;
/// profile additions and tombstones resolve identically over both.
@Suite("Profile float/ignore apply (#287)", .serialized)
@MainActor
struct ProfileListRulesApplyTests {
    private func makeCore(
        guiManaged: Bool = true,
        staleSidecar: Bool = false
    ) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-list-rules-\(UUID().uuidString)"
                )
        )
        if guiManaged {
            var config = GuiConfig()
            config.floatRules = [
                "base.float",
                "shared.app:Base Panel",
            ]
            config.ignoreRules = ["base.ignore", "shared.ignore"]
            try core.guiConfigStore.save(config)
        } else {
            if staleSidecar {
                var stale = GuiConfig()
                stale.floatRules = ["wrong.float"]
                stale.ignoreRules = ["wrong.ignore"]
                try core.guiConfigStore.save(stale)
            }
            try FileManager.default.createDirectory(
                at: core.configDirectory,
                withIntermediateDirectories: true
            )
            let lua = """
                float_rules = {
                    "base.float",
                    "shared.app:Base Panel"
                }
                ignore_rules = { "base.ignore", "shared.ignore" }
                """
            try lua.write(
                to: core.configURL,
                atomically: true,
                encoding: .utf8
            )
            core.loadConfig()
        }
        return core
    }

    private var floatOverride: RuleListOverride {
        RuleListOverride(rules: [
            "base.float": nil,
            "profile.float": true,
            "stale.float": nil,
        ])
    }

    private var ignoreOverride: RuleListOverride {
        RuleListOverride(rules: [
            "base.ignore": nil,
            "profile.ignore": true,
            "stale.ignore": nil,
        ])
    }

    private func profile(
        named name: String,
        withOverrides: Bool
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaceModes: [:],
            settings: TilingSettings(),
            floatRules: withOverrides ? floatOverride : nil,
            ignoreRules: withOverrides ? ignoreOverride : nil
        )
    }

    private func load(
        _ name: String,
        into core: KiwiCore
    ) throws {
        try core.profiles.save(
            profile(named: name, withOverrides: name == "Work")
        )
        let result = core.execute(
            "load_profile",
            args: [.string(name)]
        )
        #expect(result.isSuccess)
    }

    private func expectOverrides(_ core: KiwiCore) {
        #expect(
            !core.eventLoop.floatRules.matches(
                bundleID: "base.float",
                title: ""
            )
        )
        #expect(
            core.eventLoop.floatRules.matches(
                bundleID: "profile.float",
                title: ""
            )
        )
        #expect(
            core.eventLoop.floatRules.matches(
                bundleID: "shared.app",
                title: "Base Panel"
            )
        )
        #expect(
            !core.eventLoop.ignoreRules.matches(
                bundleID: "base.ignore"
            )
        )
        #expect(
            core.eventLoop.ignoreRules.matches(
                bundleID: "profile.ignore"
            )
        )
        #expect(
            core.eventLoop.ignoreRules.matches(
                bundleID: "shared.ignore"
            )
        )
    }

    @Test("GUI base resolves additions and tombstones")
    func guiBaseResolves() throws {
        let core = try makeCore()
        try load("Work", into: core)
        expectOverrides(core)
    }

    @Test("Profile switch restores the global base")
    func plainProfileRestoresBase() throws {
        let core = try makeCore()
        try load("Work", into: core)
        try load("Plain", into: core)

        #expect(
            core.eventLoop.floatRules.matches(
                bundleID: "base.float",
                title: ""
            )
        )
        #expect(
            !core.eventLoop.floatRules.matches(
                bundleID: "profile.float",
                title: ""
            )
        )
        #expect(
            core.eventLoop.ignoreRules.matches(
                bundleID: "base.ignore"
            )
        )
        #expect(
            !core.eventLoop.ignoreRules.matches(
                bundleID: "profile.ignore"
            )
        )
    }

    @Test("Lua base uses the same profile resolution")
    func luaBaseResolves() throws {
        let core = try makeCore(guiManaged: false)
        try load("Work", into: core)
        expectOverrides(core)
    }

    @Test("Lua base wins over an inactive sidecar")
    func luaBaseWinsOverSidecar() throws {
        let core = try makeCore(
            guiManaged: false,
            staleSidecar: true
        )
        try load("Work", into: core)

        expectOverrides(core)
        #expect(
            !core.eventLoop.floatRules.matches(
                bundleID: "wrong.float",
                title: ""
            )
        )
        #expect(
            !core.eventLoop.ignoreRules.matches(
                bundleID: "wrong.ignore"
            )
        )
    }

    @Test("Reload keeps the active list-rule overrides")
    func reloadKeepsOverrides() throws {
        let core = try makeCore()
        try load("Work", into: core)

        core.loadConfig()

        expectOverrides(core)
    }

    @Test("Ignore tombstone exposes effective app and float rules")
    func ignoreTombstoneExposesOtherRules() throws {
        let core = try makeCore()
        let target = "shared.ignore"
        var removedIgnore: [String: Bool?] = [:]
        removedIgnore.updateValue(nil, forKey: target)
        try core.profiles.save(
            Profile(
                name: "Exposed",
                monitorSets: [MonitorSet(monitors: [])],
                spaceModes: [:],
                settings: TilingSettings(),
                appRules: AppRuleOverride(rules: [
                    target: SpaceID(2)
                ]),
                floatRules: RuleListOverride(rules: [target: true]),
                ignoreRules: RuleListOverride(rules: removedIgnore)
            )
        )

        let result = core.execute(
            "load_profile",
            args: [.string("Exposed")]
        )

        #expect(result.isSuccess)
        #expect(!core.eventLoop.ignoreRules.matches(bundleID: target))
        #expect(
            core.eventLoop.floatRules.matches(
                bundleID: target,
                title: ""
            )
        )
        #expect(core.state.appRules[target] == SpaceID(2))
    }
}
