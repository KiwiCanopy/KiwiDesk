import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A layer chooses which profiles it belongs to (#2022), and delete
/// and rename follow that choice — draft to files, through the one
/// `saveRuleReach`.
@Suite("Layer reach (#2022)", .serialized)
@MainActor
struct LayerReachModelTests {
    private let up = "KiwiDesk.focus(\"up\")"

    private var switchRow: KeyBinding {
        let cmd = KeybindingCatalog.switchLayerCommand("Gaming")
        return KeyBinding(
            combo: "alt+g",
            lua: cmd.lua,
            kind: .navigation,
            label: cmd.label
        )
    }

    /// gui.json shares Gaming and a switch to it; Work is loaded,
    /// Home and Travel are stored, and Home carries a layer of its
    /// own named Focus.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [switchRow]),
            KeyLayer(
                name: "Gaming",
                bindings: [KeyBinding(combo: "w", lua: up, kind: .navigation)]
            ),
        ]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        var home = profile("Home")
        home.layers = KeyLayerOverride(layers: [KeyLayer(name: "Focus")])
        try core.profiles.write(home)
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

    private func layers(_ model: SettingsModel, _ name: String) throws
        -> [KeyLayer]
    {
        let base = model.core.guiConfigStore.load()?.layers ?? []
        return try model.core.profiles.read(name: name).layers?
            .resolved(onto: base) ?? base
    }

    private func names(_ model: SettingsModel, _ name: String) throws
        -> [String]
    {
        try layers(model, name).map(\.name)
    }

    private var baseNames: (SettingsModel) -> [String] {
        { $0.core.guiConfigStore.load()?.layers.map(\.name) ?? [] }
    }

    @Test("a shared layer reads as every profile's")
    func sharedReading() throws {
        let model = try makeModel()
        let row = try #require(model.layerReach("Gaming"))
        #expect(row.shared)
        #expect(row.users == ["Work", "Home", "Travel"])
    }

    @Test("unticking a profile leaves it out and keeps the layer shared")
    func untickLeavesOut() throws {
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Home", false)
        #expect(model.isDirty)
        #expect(
            model.layerDiffRows().map(\.id).contains {
                $0.contains("layer.Gaming.Home")
            }
        )
        model.updateActiveProfile()

        #expect(
            try model.core.profiles.read(name: "Home").layers?.leftOut
                == ["Gaming"]
        )
        #expect(baseNames(model) == [KeyLayer.defaultName, "Gaming"])
        #expect(try names(model, "Travel").contains("Gaming"))
        #expect(!model.isDirty)
    }

    @Test("ticking a profile back is no edit at all")
    func tickBackIsInert() throws {
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Home", false)
        model.setLayerProfile("Gaming", "Home", true)
        #expect(model.reachEdits.isEmpty)
        #expect(!model.isDirty)
    }

    @Test("Delete from Work leaves Work out, switch rows and all")
    func deleteHere() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .here)
        model.updateActiveProfile()

        let work = try layers(model, "Work")
        #expect(!work.contains { $0.name == "Gaming" })
        #expect(
            !work.flatMap(\.bindings).contains { $0.lua == switchRow.lua }
        )
        #expect(baseNames(model) == [KeyLayer.defaultName, "Gaming"])
        #expect(try names(model, "Home").contains("Gaming"))
        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(base[0].bindings.contains { $0.lua == switchRow.lua })
    }

    @Test("Delete from every profile takes the layer out of the base")
    func deleteEverywhere() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .everywhere)
        #expect(
            model.layerDiffRows().map(\.id).contains {
                $0.contains("layer.Gaming.deleted")
            }
        )
        model.updateActiveProfile()

        #expect(baseNames(model) == [KeyLayer.defaultName])
        #expect(try !names(model, "Home").contains("Gaming"))
        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(!base[0].bindings.contains { $0.lua == switchRow.lua })
    }

    @Test("a rename reaches every profile that has the layer")
    func renameReaches() throws {
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Travel", false)
        model.updateActiveProfile()
        model.renameLayer("Gaming", to: "Play")
        model.updateActiveProfile()

        #expect(baseNames(model) == [KeyLayer.defaultName, "Play"])
        #expect(try names(model, "Home").contains("Play"))
        // Travel was not in the layer, so the rename leaves it out.
        #expect(try !names(model, "Travel").contains("Play"))
        let play = KeybindingCatalog.switchLayerCommand("Play").lua
        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(base[0].bindings.contains { $0.lua == play })
    }

    @Test("a clash is checked only where the rename reaches")
    func clashWhereReached() throws {
        let model = try makeModel()
        #expect(model.layerRenameClash("Gaming", "Focus") == "Home")
        model.setLayerProfile("Gaming", "Home", false)
        #expect(model.layerRenameClash("Gaming", "Focus") == nil)
    }

    @Test("a new layer starts where a new row does")
    func newLayerDefaults() throws {
        let model = try makeModel()
        model.config.layers.append(KeyLayer(name: "Fresh"))
        #expect(try #require(model.layerReach("Fresh")).shared)

        model.selectEditTarget("Home")
        model.config.layers.append(KeyLayer(name: "Fresh"))
        let stored = try #require(model.layerReach("Fresh"))
        #expect(!stored.shared && stored.users == ["Home"])
    }

    @Test("an empty layer of one profile deletes without asking")
    func deleteAsks() throws {
        let model = try makeModel()
        #expect(model.layerDeleteAsks("Gaming"))
        model.config.layers.append(
            KeyLayer(
                name: "Chrome",
                bindings: DefaultKeybindings.appChromeRows()
            )
        )
        // Off All profiles it is still every current profile's; the
        // ticks take it down to Work's alone.
        model.setLayerAllProfiles("Chrome", false)
        #expect(model.layerDeleteAsks("Chrome"))
        model.setLayerProfile("Chrome", "Home", false)
        model.setLayerProfile("Chrome", "Travel", false)
        #expect(!model.layerDeleteAsks("Chrome"))
        // Its own rows and the row that switches to it.
        #expect(model.layerDeleteCount("Gaming") == 2)
    }

    @Test("a shortcut's checklist greys a profile without its layer")
    func rowGreysLackingProfile() throws {
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Travel", false)
        let key = RuleReachTable<String>.keyID(layer: "Gaming", lua: up)
        let row = try #require(model.keyReach(key))
        #expect(row.lacking == ["Travel"])
    }
}
