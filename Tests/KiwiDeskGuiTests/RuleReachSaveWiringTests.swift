import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The three save wirings a byte-identical re-encode cannot show
/// (#1393, guard-prover): a profile the change did not reach keeps
/// its FILE, the float half of the shared-rule swap, and the paused
/// globals Save carrying the checklist.
@Suite("Rule reach save wiring (#1393)", .serialized)
@MainActor
struct RuleReachSaveWiringTests {
    /// gui.json floats Calculator; Work (loaded) also floats Zoom on
    /// its own; Home and Travel are stored.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.appRules = ["mail": SpaceID("1")]
        config.floatRules = ["com.calc"]
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.floatRules = RuleListOverride(rules: ["zoom": true])
        try core.profiles.save(work)
        try core.profiles.write(profile("Home"))
        try core.profiles.write(profile("Travel"))
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

    @Test("A profile the change did not reach keeps its file")
    func unreachedFileUntouched() throws {
        let model = try makeModel()
        let url = try model.core.profiles.fileURL(name: "Travel")
        // Hand-formatted, so any re-encode would change the bytes.
        let text = try String(contentsOf: url, encoding: .utf8)
        let marked = "\n\n" + text + "\n\n"
        try marked.write(to: url, atomically: true, encoding: .utf8)
        model.reload()

        // Mail moves for Work and Home; Travel, unticked, keeps it.
        model.setAllProfiles(.space, "mail", false)
        model.setProfile(.space, "mail", "Travel", false)
        model.config.appRules["mail"] = SpaceID("2")
        model.updateActiveProfile()

        #expect(
            try model.core.profiles.read(name: "Home").appRules
                == AppRuleOverride(rules: ["mail": SpaceID("2")])
        )
        #expect(try model.core.profiles.read(name: "Travel").appRules == nil)
        let after = try String(contentsOf: url, encoding: .utf8)
        #expect(after == marked)
    }

    @Test("The loaded page's own float rule stays out of gui.json")
    func floatSwapOnLiveSave() throws {
        let model = try makeModel()
        #expect(model.config.floatRules.contains("zoom"))

        // Any global change makes the Save write gui.json.
        model.config.ignoreRules = ["com.example.ignored"]
        model.updateActiveProfile()

        let base = model.core.guiConfigStore.load()?.floatRules ?? []
        #expect(base == ["com.calc"])
    }

    @Test("The paused globals Save writes the checklist too")
    func pausedSaveCarriesReach() throws {
        let model = try makeModel()
        model.setAllProfiles(.space, "mail", false)
        model.setProfile(.space, "mail", "Home", false)
        model.config.appRules["mail"] = SpaceID("2")

        model.saveGlobalsWhilePaused()

        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"] == SpaceID("1")
        )
        #expect(
            try model.core.profiles.read(name: "Work").appRules
                == AppRuleOverride(rules: ["mail": SpaceID("2")])
        )
    }
}
