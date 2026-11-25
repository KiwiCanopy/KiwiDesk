import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A layer edit carries the layer's gesture maps in the files, not
/// only in the draft (#3535): the layer pass renames the shared
/// base's and each profile's map with the layer, drops them with a
/// delete everywhere, keeps the base on a delete here, and drops a
/// profile's own map when the profile leaves the layer. Work is
/// loaded and edited; Home carries its own "Coding" map, Away one
/// for a layer it leaves out. Main-actor
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
        // Away leaves Coding out yet still holds a map for it.
        var away = profile("Away", LayerGestures(["Coding": home]))
        away.layers = KeyLayerOverride(leftOut: ["Coding"])
        try core.profiles.write(away)
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
        #expect(pass.gestures.gestureOverride(for: "Away") == nil)
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

    @Test("a profile leaving the layer leaves its gesture picks")
    func leavingDropsThePick() throws {
        let model = try model()
        let row = LayerGestureKey("Coding", swipe).spelling
        var edits = model.reachEdits
        edits.reach[.gesture] = [row: .listed(["Work", "Home"])]
        model.reachEdits = edits
        model.setLayerProfile("Coding", "Home", false)
        #expect(model.reachEdits.reach[.gesture]?[row] == .listed(["Work"]))
        let encoded = try #require(model.encodedReach)
        #expect(encoded.gestures.gestureOverride(for: "Home") == nil)
    }

    @Test("a layer's revert brings its gestures back")
    func revertRestores() throws {
        let model = try model()
        model.deleteLayer("Coding", .here)
        #expect(model.config.gesture["Coding"].isEmpty)
        model.revertLayer(stored: "Coding", page: nil)
        #expect(model.config.gesture["Coding"] == shared)
        let encoded = try #require(model.encodedReach)
        #expect(
            encoded.gestures.gestureBase(
                original: encoded.storedGestureBase,
                shortcutBase: .standard
            ) == LayerGestures(["Coding": shared])
        )
    }

    @Test("a renamed layer's revert brings its gestures back")
    func renameRevertRestores() throws {
        let model = try model()
        model.renameLayer("Coding", to: "Code")
        model.revertLayer(stored: "Coding", page: "Code")
        #expect(model.config.gesture["Code"].isEmpty)
        #expect(model.config.gesture["Coding"] == shared)
    }

    /// The revert reads the clean gestures on the draft's base, as
    /// the layer's rows do.
    @Test("a revert under a base switch brings gestures on that base")
    func revertFollowsTheBase() throws {
        let model = try model()
        model.deleteLayer("Coding", .here)
        model.config.shortcutBase = .hyper
        model.revertLayer(stored: "Coding", page: nil)
        let moved = GestureKey(.swipe3, [.hyper])
        #expect(model.config.gesture["Coding"][moved] != nil)
        #expect(model.config.gesture["Coding"][swipe] == nil)
    }

    /// A new row on a layer only Work holds stays Work's: a shared
    /// pick there would write the layer's map into the base.
    @Test("a row on an unshared layer lands on its holders alone")
    func unsharedLayerStaysOwn() throws {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        var work = profile("Work", nil)
        work.layers = KeyLayerOverride(layers: [KeyLayer(name: "Solo")])
        try core.profiles.save(work)
        try core.profiles.write(profile("Home", nil))
        let model = makeTestModel(core: core)
        model.reload()
        model.nav.shortcutsLayer = "Solo"
        model.gestureLayerMap[tap] = .bound(.run(LuaAction(lua: "y()")))
        let encoded = try #require(model.encodedReach)
        let base = encoded.gestures.gestureBase(
            original: encoded.storedGestureBase,
            shortcutBase: .standard
        )
        #expect(base["Solo"].isEmpty)
        #expect(
            encoded.gestures.gestureOverride(for: "Work")?["Solo"][tap] != nil
        )
        #expect(encoded.gestures.gestureOverride(for: "Home") == nil)
    }
}
