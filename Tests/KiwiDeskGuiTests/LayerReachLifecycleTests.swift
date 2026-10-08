import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A layer's identity across a draft (#2022 review): renames land
/// at once, a new layer is never a stored one, row picks follow
/// the layer they key, and a stored page locks on the files.
@Suite("Layer reach lifecycle (#2022)", .serialized)
@MainActor
struct LayerReachLifecycleTests {
    private let up = "KiwiDesk.focus(\"up\")"
    private let chat = "KiwiDesk.focus(\"down\")"

    /// gui.json shares Gaming and Chat; Work is loaded, Home and
    /// Travel stored, and Home carries a layer of its own, Focus.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName),
            layer("Gaming", "w", up),
            layer("Chat", "c", chat),
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

    private func layer(_ name: String, _ combo: String, _ lua: String)
        -> KeyLayer
    {
        KeyLayer(
            name: name,
            bindings: [KeyBinding(combo: combo, lua: lua, kind: .navigation)]
        )
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

    private func rows(_ layers: [KeyLayer], _ name: String) -> [String] {
        layers.first { $0.name == name }?.bindings.map(\.lua) ?? []
    }

    private func key(_ layer: String, _ lua: String) -> String {
        RuleReachTable<String>.keyID(layer: layer, lua: lua)
    }

    @Test("a rename chain lands at once and merges nothing")
    func renameChain() throws {
        let model = try makeModel()
        model.renameLayer("Gaming", to: "Play")
        model.renameLayer("Chat", to: "Gaming")
        model.updateActiveProfile()

        let home = try layers(model, "Home")
        #expect(rows(home, "Play") == [up])
        #expect(rows(home, "Gaming") == [chat])
    }

    @Test("a new layer named like a renamed one is never the stored one")
    func newLayerIsNew() throws {
        let model = try makeModel()
        model.renameLayer("Gaming", to: "Play")
        model.config.layers.append(KeyLayer(name: "Gaming"))
        #expect(model.storedLayer("Gaming") == nil)
        model.deleteLayer("Gaming", .everywhere)
        model.updateActiveProfile()

        #expect(rows(try layers(model, "Home"), "Play") == [up])
    }

    @Test("Delete from Work drops a row pick of the layer")
    func deleteHereDropsRowPick() throws {
        let model = try makeModel()
        model.setAllProfiles(.key, key("Gaming", up), false)
        model.deleteLayer("Gaming", .here)
        model.updateActiveProfile()

        #expect(rows(try layers(model, "Home"), "Gaming") == [up])
        #expect(!(try layers(model, "Work")).contains { $0.name == "Gaming" })
    }

    @Test("unticking a profile trims a row pick that listed it")
    func untickTrimsRowPick() throws {
        let model = try makeModel()
        model.setAllProfiles(.key, key("Gaming", up), false)
        model.setLayerProfile("Gaming", "Home", false)
        model.updateActiveProfile()

        #expect(!(try layers(model, "Home")).contains { $0.name == "Gaming" })
        #expect(rows(try layers(model, "Travel"), "Gaming") == [up])
    }

    @Test("a stored page locks on the files, not on its own ticks")
    func lockReadsStoredFiles() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        #expect(model.layerLockedHere("Gaming"))
        #expect(!model.layerLockedHere("Focus"))
        model.setLayerProfile("Focus", "Travel", true)
        #expect(!model.layerLockedHere("Focus"))
    }

    @Test("a profile left out of a shared layer is reached by its rename")
    func leftOutClash() throws {
        let model = try makeModel()
        model.setLayerProfile("Gaming", "Home", false)
        #expect(model.layerRenameClash("Gaming", "Focus") == "Home")
        model.updateActiveProfile()
        #expect(model.layerRenameClash("Gaming", "Focus") == "Home")
    }
}
