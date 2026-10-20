import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A shortcut, layer or lens row's ↺ in the draft (#2412): a
/// binding takes back itself and the bindings its chord moved
/// between, at once; a layer or a lens goes back whole, asking
/// first. Locale pinned per body (#740).
@Suite("Shortcut, layer and lens revert (#2412)", .serialized)
@MainActor
struct SettingsShortcutRevertTests {
    private let left = "KiwiDesk.focus(\"left\")"
    private let swap = "KiwiDesk.swap(\"left\")"
    private let writing = KeybindingCatalog.toggleLens("Writing").lua

    /// gui.json binds focus left to H, swap left to J and Writing to
    /// W, with a Gaming layer; Work is loaded.
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
                    KeyBinding(combo: "ctrl+alt+w", lua: writing),
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
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: [])],
                spaces: [SpaceID("1")],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func rows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model)
    }

    /// The recorder's steal, by hand: swap left takes H.
    private func moveH(_ model: SettingsModel) {
        model.config.layers[0].bindings.removeAll { $0.lua == left }
        model.config.layers[0].bindings[0].combo = "ctrl+alt+h"
    }

    @Test("a binding's ↺ takes the move back, from either row")
    func moveRevertsBoth() throws {
        LocalizationManager.shared.select("en")
        for side in [left, swap] {
            let model = try makeModel()
            let saved = model.config.layers
            moveH(model)
            let row = try #require(
                rows(model).first {
                    $0.revert
                        == .binding(
                            layer: KeyLayer.defaultName,
                            lua: side
                        )
                }
            )
            #expect(!model.revertTakesGroup(row))
            #expect(model.revertCompanions(row).count == 1)
            model.revert(row)
            #expect(model.config.layers == saved)
            #expect(rows(model).isEmpty)
        }
    }

    @Test("a plain rebind takes its own row alone")
    func rebindIsOneRow() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.config.layers[0].bindings[0].combo = "ctrl+alt+y"
        model.config.layers[1].bindings[0].combo = "ctrl+alt+z"
        let row = try #require(
            rows(model).first {
                $0.revert == .binding(layer: "Gaming", lua: left)
            }
        )
        #expect(model.revertCompanions(row).isEmpty)
        model.revert(row)
        #expect(model.config.layers[1].bindings[0].combo == "ctrl+alt+g")
        #expect(model.config.layers[0].bindings[0].combo == "ctrl+alt+y")
    }

    /// A binding's reach pick goes back with it.
    @Test("a binding's ↺ drops its reach pick")
    func reachPickGoes() throws {
        let model = try makeModel()
        model.config.layers[0].bindings[0].combo = "ctrl+alt+y"
        let key = RuleReachTable<String>.keyID(
            layer: KeyLayer.defaultName,
            lua: left
        )
        model.reachEdits.reach[.key] = [key: .listed(["Work"])]
        model.revertBinding(layer: KeyLayer.defaultName, lua: left)
        #expect(model.reachEdits.reach[.key]?[key] == nil)
    }

    @Test("a layer added in the draft goes, asking first")
    func addedLayerGoes() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.config.layers.append(KeyLayer(name: "Writing", bindings: []))
        let row = try #require(
            rows(model).first {
                $0.revert == .layer(stored: nil, page: "Writing")
            }
        )
        #expect(model.revertTakesGroup(row))
        model.revert(row)
        #expect(!model.config.layers.contains { $0.name == "Writing" })
    }

    @Test("a deleted layer comes back with its bindings")
    func deletedLayerReturns() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let saved = model.config.layers
        model.deleteLayer("Gaming", .everywhere)
        let row = try #require(
            rows(model).first {
                $0.revert == .layer(stored: "Gaming", page: nil)
            }
        )
        model.revert(row)
        #expect(model.config.layers == saved)
        #expect(model.reachEdits.deletedLayers.isEmpty)
    }

    /// Both rows of a rename name one layer: either takes it back.
    @Test("a renamed layer takes its old name back, from either row")
    func renamedLayerReturns() throws {
        LocalizationManager.shared.select("en")
        for side in [
            SettingsRowRevert.layer(stored: "Gaming", page: nil),
            .layer(stored: nil, page: "Play"),
        ] {
            let model = try makeModel()
            let saved = model.config.layers
            model.renameLayer("Gaming", to: "Play")
            let row = try #require(rows(model).first { $0.revert == side })
            model.revert(row)
            #expect(model.config.layers == saved)
            #expect(model.reachEdits.layers.isEmpty)
        }
    }

    @Test("a deleted lens comes back with its chord, asking first")
    func deletedLensReturns() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let saved = model.config.layers
        model.deleteLens("Writing")
        let row = try #require(
            rows(model).first {
                $0.revert == .lens(stored: "Writing", page: nil)
            }
        )
        #expect(model.revertTakesGroup(row))
        model.revert(row)
        #expect(model.reachEdits.lenses == nil)
        #expect(model.config.layers == saved)
    }

    @Test("a renamed lens takes its name and chord back")
    func renamedLensReturns() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let saved = model.config.layers
        model.renameLens("Writing", to: "Reading")
        let row = try #require(
            rows(model).first {
                $0.revert == .lens(stored: "Writing", page: "Reading")
            }
        )
        model.revert(row)
        #expect(model.reachEdits.lenses == nil)
        #expect(model.config.layers == saved)
    }

    @Test("a new lens goes")
    func newLensGoes() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.addLens(named: "Reading")
        let row = try #require(
            rows(model).first {
                $0.revert == .lens(stored: nil, page: "Reading")
            }
        )
        model.revert(row)
        #expect(model.reachEdits.lenses == nil)
    }

    @Test("a lens's edit goes back, its name kept")
    func lensFieldsReturn() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.updateLens("Writing") { $0.apps = ["com.apple.TextEdit"] }
        let row = try #require(
            rows(model).first { $0.revert == .lensFields(page: "Writing") }
        )
        #expect(!model.revertTakesGroup(row))
        model.revert(row)
        #expect(model.reachEdits.lenses == nil)
    }
}
