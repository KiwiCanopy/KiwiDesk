import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A layer edit carries the layer's gesture maps in the files, not
/// only in the draft (#3535): the layer pass renames the shared
/// base's and each profile's map with the layer, drops them with a
/// delete everywhere, keeps the base on a delete here, and drops a
/// profile's own map when the profile leaves the layer. Work is
/// loaded and edited; Home carries its own "Coding" map. Main-actor
/// spend: one test core, three small file writes and one model
/// reload per test; no scan, no AppKit layout.
@Suite("Layer pass over gestures (#3535)", .serialized)
@MainActor
struct LayerPassGestureTests {
    private let swipe = GestureKey(.swipe3, [.control, .option])
    private let tap = GestureKey(.tap5)

    private var shared: GestureMap {
        GestureMap([swipe: .bound(.family(.space))])
    }

    private var home: GestureMap {
        GestureMap([tap: .bound(.run(LuaAction(lua: "x()")))])
    }

    private func model() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [KeyLayer.defaultLayer, KeyLayer(name: "Coding")]
        config.gesture = LayerGestures(["Coding": shared])
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work", nil))
        try core.profiles.write(
            profile("Home", LayerGestures(["Coding": home]))
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String, _ gesture: LayerGestures?) -> Profile
    {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings(),
            gesture: gesture
        )
    }

    @Test("a rename carries the base's and each profile's map")
    func renameCarries() throws {
        let model = try model()
        model.renameLayer("Coding", to: "Code")
        let pass = try #require(model.layeredReach)
        #expect(pass.storedGestureBase == LayerGestures(["Code": shared]))
        #expect(
            pass.gestures.gestureOverride(for: "Home")
                == LayerGestures(["Code": home])
        )
    }

    @Test("a delete everywhere drops every file's map")
    func deleteEverywhereDrops() throws {
        let model = try model()
        model.deleteLayer("Coding", .everywhere)
        let pass = try #require(model.layeredReach)
        #expect(pass.storedGestureBase.isEmpty)
        #expect(pass.gestures.gestureOverride(for: "Home") == nil)
    }

    @Test("a delete here keeps the base and writes no tombstones")
    func deleteHereKeepsTheBase() throws {
        let model = try model()
        model.deleteLayer("Coding", .here)
        let pass = try #require(model.layeredReach)
        #expect(pass.storedGestureBase == LayerGestures(["Coding": shared]))
        let encoded = try #require(model.encodedReach)
        #expect(encoded.gestures.gestureOverride(for: "Work") == nil)
        #expect(
            encoded.gestures.gestureBase(
                original: encoded.storedGestureBase,
                shortcutBase: .standard
            ) == LayerGestures(["Coding": shared])
        )
    }

    @Test("a profile leaving the layer leaves its own map there")
    func leavingDropsTheOwnMap() throws {
        let model = try model()
        model.setLayerProfile("Coding", "Home", false)
        let pass = try #require(model.layeredReach)
        #expect(pass.gestures.gestureOverride(for: "Home") == nil)
        #expect(pass.storedGestureBase == LayerGestures(["Coding": shared]))
    }
}
