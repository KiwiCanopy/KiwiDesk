import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The model doors the Layers card's editor popovers read (#3263):
/// a name the page already has is refused in words, a new layer
/// takes the picked icon through Add, a rejoined shared layer keeps
/// its own, and a name not yet added reads where Add records it.
@Suite("Layer editor model (#3263)", .serialized)
@MainActor
struct LayerEditorModelTests {
    /// gui.json shares Gaming, with an icon; Work is loaded and
    /// Travel is stored.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName),
            KeyLayer(name: "Gaming", icon: "gamecontroller"),
        ]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
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

    private func icon(_ model: SettingsModel, _ name: String) -> String? {
        model.config.layers.first { $0.name == name }?.icon
    }

    @Test("a name the page has is refused in words, for Rename and Add")
    func onPageNameIsRefused() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = try makeModel()
        #expect(model.addLayer("Fresh"))
        let refusal = try #require(model.layerOnPageRefusal("Gaming"))
        #expect(refusal.contains("Gaming"))
        #expect(model.layerRenameRefusal("Fresh", "Gaming") == refusal)
        #expect(model.layerRenameRefusal("Fresh", "Fresh") == nil)
        #expect(model.layerOnPageRefusal("Nowhere") == nil)
        #expect(!model.canAddLayer("Gaming"))
    }

    @Test("a new layer takes the picked icon, an empty pick none")
    func newLayerTakesTheIcon() throws {
        let model = try makeModel()
        #expect(model.addLayer("Fresh", icon: "star"))
        #expect(icon(model, "Fresh") == "star")
        #expect(model.addLayer("Bare", icon: ""))
        #expect(icon(model, "Bare") == nil)
        #expect(model.rejoinedLayerIcon("Other") == nil)
    }

    @Test("a rejoined shared layer keeps its own icon")
    func rejoinKeepsItsIcon() throws {
        let model = try makeModel()
        model.deleteLayer("Gaming", .here)
        #expect(model.rejoinedLayerIcon("Gaming") == "gamecontroller")
        #expect(model.addLayer("Gaming", icon: "star"))
        #expect(icon(model, "Gaming") == "gamecontroller")
    }

    @Test("a name not yet added reads where Add records it")
    func pendingReachIsWhatAddRecords() throws {
        let model = try makeModel()
        let before = try #require(model.layerReach("Fresh"))
        #expect(model.addLayer("Fresh"))
        let after = try #require(model.layerReach("Fresh"))
        #expect(before.shared == after.shared)
        #expect(before.users == after.users)
    }
}
