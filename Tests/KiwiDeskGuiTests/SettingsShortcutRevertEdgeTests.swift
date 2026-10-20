import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The edges of the shortcut, layer and lens ↺ (#2412): a renamed
/// layer's bindings read under its saved name, a name taken again
/// draws no ↺, a switch or toggle row goes back with its layer or
/// lens, a restored chord takes its clash set, and the membership,
/// lens reach, icon and base rows each revert. Locale pinned per
/// body (#740).
@Suite("Shortcut revert edges (#2412)", .serialized)
@MainActor
struct SettingsShortcutRevertEdgeTests {
    private let left = "KiwiDesk.focus(\"left\")"
    private let writing = KeybindingCatalog.toggleLens("Writing").lua
    private let toGaming = KeybindingCatalog.switchLayerCommand("Gaming").lua

    /// gui.json: focus left on H, Writing on W and a switch to
    /// Gaming on G in the default layer; Gaming binds focus left to
    /// J. Lenses Writing then Reading. Work is loaded, Home saved.
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
            $0.visionLenses = [
                VisionLens(name: "Writing"), VisionLens(name: "Reading"),
            ]
        }
        try core.profiles.save(profile("Work"))
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

    private func rows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model)
    }

    private func gaming(_ model: SettingsModel) -> [KeyBinding] {
        model.config.layers.first { $0.name == "Play" }?.bindings ?? []
    }

    /// The binding of a renamed layer reverts to its saved chord,
    /// never out of the layer.
    @Test("a renamed layer's binding reverts to its saved chord")
    func renamedLayerBinding() throws {
        let model = try makeModel()
        model.renameLayer("Gaming", to: "Play")
        let at = try #require(
            model.config.layers.firstIndex { $0.name == "Play" }
        )
        model.config.layers[at].bindings[0].combo = "ctrl+alt+y"
        model.revertBinding(layer: "Play", lua: left)
        #expect(gaming(model).map(\.combo) == ["ctrl+alt+j"])
    }

    /// Delete Gaming, then add a new Gaming: the old one cannot come
    /// back under its name, so its row draws no ↺.
    @Test("a layer whose name is taken again draws no ↺")
    func takenLayerNameBlocks() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.deleteLayer("Gaming", .everywhere)
        model.config.layers.append(KeyLayer(name: "Gaming", bindings: []))
        let row = SettingsDiffRow.note(
            .shortcuts(.layers),
            label: "Gaming",
            note: "removed"
        )
        var deleted = row
        deleted.revert = .layer(stored: "Gaming", page: nil)
        #expect(!model.canRevert(deleted))
    }

    @Test("a lens whose name is taken again draws no ↺")
    func takenLensNameBlocks() throws {
        let model = try makeModel()
        model.renameLens("Writing", to: "Notes")
        model.addLens(named: "Writing")
        var row = SettingsDiffRow.note(
            .kiwiVision(.lenses),
            label: "Writing",
            note: "renamed"
        )
        row.revert = .lens(stored: "Writing", page: "Notes")
        #expect(!model.canRevert(row))
    }

    /// A rename's switch rows revert with the layer, never alone.
    @Test("a renamed layer's switch row reverts with the layer")
    func switchRowOwnedByLayer() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.renameLayer("Gaming", to: "Play")
        let switches = rows(model).filter {
            $0.key == .shortcuts(.layers) && $0.subject != nil
        }
        #expect(!switches.isEmpty)
        for row in switches {
            guard case .layer(let stored, _) = row.revert else {
                Issue.record("\(row.label) reverts \(row.revert)")
                continue
            }
            #expect(stored == "Gaming")
        }
    }

    /// Delete Writing, give focus left its free chord, revert the
    /// lens: focus left goes back too, so no chord is held twice.
    @Test("a lens's chord comes back with its clash set")
    func lensChordTakesItsClash() throws {
        let model = try makeModel()
        let saved = model.config.layers
        model.deleteLens("Writing")
        model.config.layers[0].bindings[0].combo = "ctrl+alt+w"
        model.revertLens(stored: "Writing", page: nil)
        #expect(model.config.layers == saved)
    }

    /// The deleted lens returns at its stored place, before Reading.
    @Test("a deleted lens returns at its stored place")
    func lensKeepsItsPlace() throws {
        let model = try makeModel()
        model.deleteLens("Writing")
        model.revertLens(stored: "Writing", page: nil)
        #expect(model.reachEdits.lenses == nil)
        #expect(model.draftLenses.map(\.name) == ["Writing", "Reading"])
    }

    @Test("a lens's reach pick goes back")
    func lensReachReverts() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.setLensReach("Writing", ["Work"])
        let row = try #require(
            rows(model).first {
                $0.revert == .lensReach(page: "Writing", profile: "Home")
            }
        )
        model.revert(row)
        #expect(model.reachEdits.lenses == nil)
    }

    @Test("a layer's membership of a profile goes back")
    func layerMembershipReverts() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Home", false)
        let row = try #require(
            rows(model).first {
                $0.revert == .layerMembers(page: "Gaming", profile: "Home")
            }
        )
        model.revert(row)
        #expect(model.reachEdits.layers.isEmpty)
    }

    @Test("a layer's icon goes back alone")
    func layerIconReverts() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.config.layers[1].icon = "gamecontroller"
        model.config.layers[0].icon = "star"
        let row = try #require(
            rows(model).first {
                $0.key == .shortcuts(.layersIcon) && $0.instance == "Gaming"
            }
        )
        #expect(!model.revertTakesGroup(row))
        model.revert(row)
        #expect(model.config.layers[1].icon == nil)
        #expect(model.config.layers[0].icon == "star")
    }

    /// The base row moves the switched rows back, nothing more.
    @Test("the shortcut base goes back with the rows it moved")
    func shortcutBaseReverts() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        let saved = model.config
        model.setShortcutBase(.hyper)
        let row = try #require(
            rows(model).first { $0.key == .shortcuts(.shortcutBase) }
        )
        #expect(!model.revertTakesGroup(row))
        model.revert(row)
        #expect(model.config.shortcutBase == saved.shortcutBase)
        #expect(model.config.layers == saved.layers)
    }

    /// A shortcut's reach row reverts the binding it names, and
    /// names the same companions its binding row does.
    @Test("a shortcut's reach row reverts its binding")
    func reachRowReverts() throws {
        let model = try makeModel()
        model.config.layers[0].bindings[0].combo = "ctrl+alt+y"
        let key = RuleReachTable<String>.keyID(
            layer: KeyLayer.defaultName,
            lua: left
        )
        var row = SettingsDiffRow.note(
            .shortcuts(.layers),
            label: "Home",
            note: "reach"
        )
        row.revert = .ruleReach(app: key)
        #expect(model.canRevert(row))
        model.revert(row)
        #expect(model.config.layers[0].bindings[0].combo == "ctrl+alt+h")
    }
}
