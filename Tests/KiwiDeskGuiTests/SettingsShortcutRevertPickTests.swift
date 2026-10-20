import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The reach picks and name reuse a layer or lens ↺ handles (#2412):
/// a companion it restores loses its pick, a lens rename carries its
/// toggle's pick, and a reused name's own rows keep their ↺.
@Suite("Shortcut revert, picks and reused names (#2412)", .serialized)
@MainActor
struct SettingsShortcutRevertPickTests {
    private let left = "KiwiDesk.focus(\"left\")"
    private let writing = KeybindingCatalog.toggleLens("Writing").lua
    private let toGaming = KeybindingCatalog.switchLayerCommand("Gaming").lua

    /// gui.json: focus left on H, Writing on W and a switch to
    /// Gaming on G; Gaming binds focus left to J. Work is loaded.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "ctrl+alt+h", lua: left),
                    KeyBinding(combo: "ctrl+alt+w", lua: writing),
                    KeyBinding(combo: "ctrl+alt+g", lua: toGaming),
                ]
            ),
            KeyLayer(
                name: "Gaming",
                bindings: [KeyBinding(combo: "ctrl+alt+j", lua: left)]
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

    private func key(_ lua: String) -> String {
        RuleReachTable<String>.keyID(layer: KeyLayer.defaultName, lua: lua)
    }

    /// Focus left takes the chord a deleted layer's switch freed,
    /// with a pick: the layer's revert takes it back, pick and all.
    @Test("a layer's revert drops its companion's pick")
    func layerCompanionLosesPick() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .everywhere)
        model.config.layers[0].bindings[0].combo = "ctrl+alt+g"
        model.reachEdits.reach[.key] = [key(left): .listed(["Work"])]
        model.revertLayer(stored: "Gaming", page: nil)
        #expect(model.config.layers[0].bindings[0].combo == "ctrl+alt+h")
        #expect(model.reachEdits.reach[.key]?[key(left)] == nil)
    }

    @Test("a lens's revert drops its companion's pick")
    func lensCompanionLosesPick() throws {
        let model = try makeModel()
        model.deleteLens("Writing")
        model.config.layers[0].bindings[0].combo = "ctrl+alt+w"
        model.reachEdits.reach[.key] = [key(left): .listed(["Work"])]
        model.revertLens(stored: "Writing", page: nil)
        #expect(model.config.layers[0].bindings[0].combo == "ctrl+alt+h")
        #expect(model.reachEdits.reach[.key]?[key(left)] == nil)
    }

    @Test("a lens rename carries its toggle's pick")
    func lensRenameCarriesPick() throws {
        let model = try makeModel()
        model.reachEdits.reach[.key] = [key(writing): .listed(["Work"])]
        model.renameLens("Writing", to: "Focus")
        let focus = key(KeybindingCatalog.toggleLens("Focus").lua)
        #expect(model.reachEdits.reach[.key]?[writing] == nil)
        #expect(model.reachEdits.reach[.key]?[key(writing)] == nil)
        #expect(model.reachEdits.reach[.key]?[focus] == .listed(["Work"]))
    }

    /// Gaming deleted, a new Gaming added: a row switching to it is
    /// the new layer's, whose ↺ is free.
    @Test("a reused layer name's switch row keeps its ↺")
    func reusedLayerSwitchRow() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .everywhere)
        #expect(model.addLayer("Gaming"))
        let owned = model.ownedRevert(
            .binding(layer: KeyLayer.defaultName, lua: toGaming)
        )
        #expect(owned == .layer(stored: nil, page: "Gaming"))
        var row = SettingsDiffRow.note(
            .shortcuts(.layers),
            label: "Switch",
            note: "added"
        )
        row.revert = owned
        #expect(model.canRevert(row))
    }

    @Test("a reused lens name's toggle row keeps its ↺")
    func reusedLensToggleRow() throws {
        let model = try makeModel()
        model.deleteLens("Writing")
        #expect(model.addLens(named: "Writing") == nil)
        #expect(
            model.lensEditRevert("Writing")
                == .lens(stored: nil, page: "Writing")
        )
    }
}
