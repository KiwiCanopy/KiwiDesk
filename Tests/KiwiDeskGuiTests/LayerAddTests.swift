import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Every layer the page gains is a membership the layer pass places
/// (#2022 review): Add and Import record it, a shared layer's name
/// rejoins it, another profile's own name is refused, and a row is
/// never written where its layer is not.
@Suite("Layer add and import (#2022)", .serialized)
@MainActor
struct LayerAddTests {
    private let up = "KiwiDesk.focus(\"up\")"
    private let chat = "KiwiDesk.focus(\"down\")"

    private var switchRow: KeyBinding {
        let cmd = KeybindingCatalog.switchLayerCommand("Gaming")
        return KeyBinding(
            combo: "alt+g",
            lua: cmd.lua,
            kind: .navigation,
            label: cmd.label
        )
    }

    /// gui.json shares Gaming; Work is loaded, Home and Travel are
    /// stored, and Home carries a layer of its own, Focus.
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

    private func key(_ layer: String, _ lua: String) -> String {
        RuleReachTable<String>.keyID(layer: layer, lua: lua)
    }

    @Test("an imported layer lands, with its icon, where it reads")
    func importLandsWhereItReads() throws {
        let model = try makeModel()
        model.importShortcuts([
            KeyLayer(
                name: "Imported",
                icon: "star",
                bindings: [
                    KeyBinding(combo: "alt+i", lua: chat, kind: .navigation)
                ]
            )
        ])
        #expect(try #require(model.layerReach("Imported")).shared)
        model.updateActiveProfile()

        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(base.first { $0.name == "Imported" }?.icon == "star")
        #expect(try layers(model, "Travel").contains { $0.name == "Imported" })
    }

    @Test("Add refuses the name of another profile's own layer")
    func addRefusesAnOwnName() throws {
        let model = try makeModel()
        #expect(model.layerAddClash("Focus") == "Home")
        #expect(!model.addLayer("Focus"))
        #expect(!model.config.layers.contains { $0.name == "Focus" })
        #expect(model.addLayer("Fresh"))
    }

    @Test("adding a shared layer's name rejoins it after Delete here")
    func addRejoinsAfterDeleteHere() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .here)
        #expect(model.layerAddClash("Gaming") == nil)
        #expect(model.addLayer("Gaming"))
        model.updateActiveProfile()

        let work = try layers(model, "Work")
        #expect(work.contains { $0.name == "Gaming" })
        // The switch rows the delete took stay gone, here alone.
        #expect(
            !work.flatMap(\.bindings).contains { $0.lua == switchRow.lua }
        )
        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(base.contains { $0.name == "Gaming" })
        #expect(base[0].bindings.contains { $0.lua == switchRow.lua })
        // Every other holder keeps the layer.
        for other in ["Home", "Travel"] {
            #expect(
                try layers(model, other).contains { $0.name == "Gaming" }
            )
        }
    }

    /// Owner ruling (#2022): a stored page does not join a shared
    /// layer by name — that happens on the loaded profile's page.
    @Test("a stored page left out of a shared layer may not add it")
    func storedLeftOutRefused() throws {
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Home", false)
        model.updateActiveProfile()
        model.selectEditTarget("Home")
        #expect(model.layerAdmission("Gaming") == .sharedElsewhere)
        #expect(!model.canAddLayer("Gaming"))
        #expect(!model.addLayer("Gaming"))
        #expect(!model.config.layers.contains { $0.name == "Gaming" })
    }

    @Test("a stored page's new row stays its own in a listed layer")
    func storedRowStaysOwn() throws {
        let model = try makeModel()
        model.setLayerAllProfiles("Gaming", false)
        model.updateActiveProfile()
        model.selectEditTarget("Home")
        let at = try #require(
            model.config.layers.firstIndex { $0.name == "Gaming" }
        )
        model.config.layers[at].bindings.append(
            KeyBinding(combo: "q", lua: chat, kind: .navigation)
        )
        model.saveEditedProfile()

        let work = try layers(model, "Work")
        let rows = work.first { $0.name == "Gaming" }?.bindings ?? []
        #expect(!rows.contains { $0.lua == chat })
    }

    @Test("a profile without the row's layer cannot be ticked")
    func lackingProfileRefused() throws {
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Travel", false)
        model.setProfile(.key, key("Gaming", up), "Travel", true)
        #expect(model.reachEdits.reach[.key]?[key("Gaming", up)] == nil)
    }

    @Test("an imported layer named like another's own is renamed")
    func importClashIsRenamed() throws {
        let model = try makeModel()
        model.importShortcuts([
            KeyLayer(
                name: "Focus",
                bindings: [
                    KeyBinding(combo: "alt+f", lua: chat, kind: .navigation)
                ]
            )
        ])
        #expect(model.config.layers.contains { $0.name == "Focus 2" })
        #expect(!model.config.layers.contains { $0.name == "Focus" })
        model.updateActiveProfile()
        let home = try layers(model, "Home")
        #expect(home.first { $0.name == "Focus" }?.bindings.isEmpty == true)
    }

    @Test("an imported shared layer this profile left rejoins it")
    func importRejoins() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .here)
        model.importShortcuts([
            KeyLayer(
                name: "Gaming",
                bindings: [KeyBinding(combo: "w", lua: up, kind: .navigation)]
            )
        ])
        let edit = try #require(model.reachEdits.layers["Gaming"])
        #expect(edit.stored == "Gaming")
        #expect(edit.members?.shared == true)
    }

    /// A name the draft deleted is no stored layer any more: a layer
    /// added under it is new, never the deleted one come back.
    @Test("a layer deleted everywhere leaves its name free")
    func deletedNameIsNew() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .everywhere)
        #expect(model.storedLayer("Gaming") == nil)
        #expect(model.layerAdmission("Gaming") == .new)
        #expect(model.addLayer("Gaming"))
        #expect(model.reachEdits.layers["Gaming"]?.stored == nil)
        #expect(model.reachEdits.deletedLayers["Gaming"] == .everywhere)
    }
}
