import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The ↺ edges review round 2 named (#2412): the shortcut base going
/// back over a renamed layer and a row added on the staged base, a
/// new lens's reach pick, a reach row's words, and a produced row of
/// a reused layer name drawing no ↺. Locale pinned per body (#740).
@Suite("Shortcut revert, base and reach (#2412)", .serialized)
@MainActor
struct SettingsShortcutRevertBaseTests {
    private let left = "KiwiDesk.focus(\"left\")"
    private let swap = "KiwiDesk.swap(\"left\")"

    /// gui.json: focus left on H and swap left on J, Gaming binds
    /// focus left to G; lens Writing. Work is loaded, Home saved.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "ctrl+alt+h", lua: left),
                    KeyBinding(combo: "ctrl+alt+j", lua: swap),
                ]
            ),
            KeyLayer(
                name: "Gaming",
                bindings: [KeyBinding(combo: "ctrl+alt+g", lua: left)]
            ),
        ]
        try core.guiConfigStore.save(config)
        core.setAppWide(persisting: true) {
            $0.visionLenses = [VisionLens(name: "Writing")]
        }
        for name in ["Work", "Home"] {
            let profile = Profile(
                name: name,
                monitorSets: [MonitorSet(monitors: [])],
                spaces: [SpaceID("1")],
                spaceModes: [:],
                settings: TilingSettings()
            )
            if name == "Work" {
                try core.profiles.save(profile)
            } else {
                try core.profiles.write(profile)
            }
        }
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func rows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model)
    }

    /// Gaming renamed and a row added on ✦ after the switch: the
    /// base row moves both back, so no row stays on ✦.
    @Test("the base goes back over a renamed layer and an added row")
    func baseCoversRenamesAndAdditions() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.setShortcutBase(.hyper)
        model.renameLayer("Gaming", to: "Play")
        model.config.layers[0].bindings.append(
            KeyBinding(combo: "hyper+k", lua: "KiwiDesk.focus(\"right\")")
        )
        let row = try #require(
            rows(model).first { $0.key == .shortcuts(.shortcutBase) }
        )
        model.revert(row)
        let hyper = model.config.layers.flatMap(\.bindings).filter {
            KeyCombo.parse($0.combo)?.modifiers.contains(.hyper) == true
        }
        #expect(hyper.isEmpty)
        let play = model.config.layers.first { $0.name == "Play" }
        #expect(play?.bindings.first?.combo == "ctrl+alt+g")
    }

    /// A new lens reaches every profile until picked; a pick of
    /// every profile again is no edit.
    @Test("a new lens's full reach is no pick")
    func newLensFullReachIsNoPick() throws {
        let model = try makeModel()
        model.addLens(named: "Reading")
        let all = try #require(model.lensReachWithoutPick("Reading"))
        #expect(all == ["Work", "Home"])
        model.setLensReach("Reading", ["Work"])
        #expect(model.reachEdits.lenses?.reach["Reading"] == ["Work"])
        model.setLensReach("Reading", all)
        #expect(model.reachEdits.lenses?.reach["Reading"] == nil)
    }

    /// The reach row of a moved binding names the binding it takes,
    /// as the binding row does.
    @Test("a reach row's words name its companions")
    func reachRowNamesCompanions() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.config.layers[0].bindings.removeAll { $0.lua == left }
        model.config.layers[0].bindings[0].combo = "ctrl+alt+h"
        var reach = SettingsDiffRow.note(
            .shortcuts(.layers),
            label: "Home",
            note: "reach"
        )
        reach.revert = .ruleReach(
            app: RuleReachTable<String>.keyID(
                layer: KeyLayer.defaultName,
                lua: left
            )
        )
        let own = try #require(
            rows(model).first {
                $0.revert == .binding(layer: KeyLayer.defaultName, lua: left)
            }
        )
        #expect(model.revertCompanions(reach).count == 1)
        #expect(model.revertCompanions(reach) == model.revertCompanions(own))
    }

    /// Gaming deleted everywhere and a new Gaming added: the
    /// produced "deleted" row draws no ↺.
    @Test("a produced row of a reused layer name draws no ↺")
    func reusedNameRowHasNoRevert() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.deleteLayer("Gaming", .everywhere)
        model.config.layers.append(KeyLayer(name: "Gaming", bindings: []))
        let deleted = rows(model).filter {
            $0.revert == .layer(stored: "Gaming", page: nil)
        }
        #expect(!deleted.isEmpty)
        #expect(deleted.allSatisfy { !model.canRevert($0) })
    }
}
