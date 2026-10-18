import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The fold for each family the reach rows name beyond App Rules —
/// a shortcut, the owner's report, and a float rule — each joined
/// on its producer's own subject (#792). A producer that forgets
/// its subject leaves a reach row unfolded, which every case reds.
@Suite("Reach rows fold per family (#792)", .serialized)
@MainActor
struct ReachRowFoldFamilyTests {
    private let lua = "KiwiDesk.reload_config()"

    /// Work is loaded and edited; `others` are stored and follow the
    /// base.
    private func makeModel(
        _ config: GuiConfig,
        others: [String]
    ) throws -> SettingsModel {
        let core = makeTestCore()
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        for name in others { try core.profiles.write(profile(name)) }
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

    /// The rows of `family`, with every folding reach row gone.
    private func folded(
        _ model: SettingsModel,
        _ family: RuleFamily
    ) -> [SettingsDiffRow] {
        let rows = SettingsDiffRowSource.rows(for: model)
        let folding = model.reachDiffRows().filter {
            $0.subject?.family == family && $0.reach != nil
        }
        // Vacuity: a reach row asked to fold.
        #expect(!folding.isEmpty)
        for row in folding {
            #expect(!rows.contains { $0.id == row.id })
        }
        return rows.filter { $0.subject?.family == family }
    }

    @Test("a shortcut changed alike reads as one row")
    func shortcutFolds() throws {
        LocalizationManager.shared.select("en")
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "ctrl+alt+p", lua: lua, kind: .custom)
                ]
            )
        ]
        let model = try makeModel(config, others: ["Home", "Away"])
        model.config.layers[0].bindings[0].combo = "ctrl+alt+o"

        let rows = folded(model, .key)
        #expect(rows.count == 1)
        #expect(rows.first?.reach != nil)
    }

    @Test("a float rule changed alike names its reach on its notes")
    func floatFolds() throws {
        LocalizationManager.shared.select("en")
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.floatRules = ["com.apple.finder:Info"]
        let model = try makeModel(config, others: ["Home", "Away"])
        model.config.floatRules = [
            "com.apple.finder:Copy", "com.apple.finder:Move",
        ]

        let rows = folded(model, .float)
        // Two Added and one Removed note, all of one app.
        #expect(rows.count == 3)
        #expect(rows.allSatisfy { $0.reach != nil })
    }
}
