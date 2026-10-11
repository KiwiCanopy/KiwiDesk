import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Automatic floating card (#2173), draft to files: the loaded
/// page shows its profile's own Tile rule and switch, gui.json keeps
/// the shared ones, a tick writes a profile's file, and the rule
/// half drops and adopts with the others.
@Suite("Automatic floating card, draft to files (#2173)", .serialized)
@MainActor
struct AutoFloatReachModelTests {
    private let steam = "com.valvesoftware.steam"
    private let key = RuleReachTable<Bool>.floatAutomaticallyKey

    /// Work (loaded) tiles Steam and turns the switch off; Home is
    /// stored and follows the base.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.tileRules = RuleListOverride(rules: [steam: true])
        work.floatAutomatically = false
        try core.profiles.save(work)
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    @Test("the loaded page shows its own values; gui.json keeps the base")
    func loadedPageIsOwn() throws {
        let model = try makeModel()
        #expect(model.config.tileRules == [steam])
        #expect(!model.config.floatAutomatically)
        let tile = try #require(model.tileReach(steam))
        #expect(!tile.shared && tile.users == ["Work"])
        let automatic = try #require(model.autoFloatReach())
        #expect(!automatic.shared && automatic.users == ["Work"])
        #expect(model.sidecarConfig.tileRules.isEmpty)
        #expect(model.sidecarConfig.floatAutomatically)
    }

    @Test("ticking Home writes Work's values into Home's file")
    func tickHome() throws {
        let model = try makeModel()
        model.setProfile(.tile, steam, "Home", true)
        model.setProfile(.autoFloat, key, "Home", true)
        model.updateActiveProfile()
        let home = try model.core.profiles.read(name: "Home")
        #expect(
            home.tileRules?.resolved(onto: [], normalizing: { $0 })
                == [steam]
        )
        #expect(home.floatAutomatically == false)
        let sidecar = try #require(model.core.guiConfigStore.load())
        #expect(sidecar.tileRules.isEmpty)
        #expect(sidecar.floatAutomatically)
    }

    @Test("the rule half drops and adopts both")
    func ruleHalf() throws {
        let model = try makeModel()
        model.config.tileRules = []
        model.config.floatAutomatically = true
        model.dropRuleHalf()
        #expect(model.config.tileRules == [steam])
        #expect(!model.config.floatAutomatically)
        model.config.floatAutomatically = true
        model.adoptRuleHalf()
        #expect(model.cleanConfig.floatAutomatically)
    }
}
