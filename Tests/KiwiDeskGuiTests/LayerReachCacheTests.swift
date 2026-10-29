import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// `layerReach` is memoized per layer pass: every shortcut row read
/// its layer's reading, so one keystroke re-read it once per row,
/// about 135 ms of a 300 ms turn (#2783, device probe 2026-10-29).
/// A memo is only safe while each input it reads moves it, so each
/// case changes ONE input after a read and requires the next read
/// to match an uncached one.
@Suite("A layer's reach reading is memoized safely", .serialized)
@MainActor
struct LayerReachCacheTests {
    private let focus = "KiwiDesk.focus(\"left\")"
    private let reload = "KiwiDesk.reload_config()"
    private let layer = KeyLayer.defaultName
    private let gaming = "Gaming"

    /// gui.json binds focus left and shares Gaming; Work is loaded,
    /// Home stored.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "alt+h", lua: focus, kind: .navigation)
                ]
            ),
            KeyLayer(name: gaming, bindings: []),
        ]
        try core.guiConfigStore.save(config)
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

    /// The reading with the memo emptied first.
    private func uncached(_ model: SettingsModel) -> RuleReachReading? {
        model.layerCache = nil
        return model.layerReach(layer)
    }

    @Test("A read fills the memo and a second read reuses it")
    func readFillsTheMemo() throws {
        let model = try makeModel()
        let first = try #require(model.layerReach(layer))
        let cached = try #require(model.layerCache)
        #expect(cached.readings[layer] == .some(first))
        #expect(model.layerReach(layer) == first)
        #expect(model.layerCache?.key == cached.key)
    }

    @Test("A page edit after a read is seen by the next read")
    func pageEditMovesTheMemo() throws {
        let model = try makeModel()
        _ = model.layerReach(layer)
        let before = try #require(model.layerCache?.key)
        model.config.layers[0].bindings.append(
            KeyBinding(combo: "ctrl+alt+r", lua: reload, kind: .custom)
        )
        let after = model.layerReach(layer)
        #expect(model.layerCache?.key != before)
        #expect(after == uncached(model))
    }

    @Test("A layer pick after a read is seen by the next read")
    func pickMovesTheMemo() throws {
        let model = try makeModel()
        let before = try #require(model.layerReach(gaming))
        model.setLayerAllProfiles(gaming, false)
        model.setLayerProfile(gaming, "Home", false)
        let after = try #require(model.layerReach(gaming))
        #expect(after.users != before.users)
        model.layerCache = nil
        #expect(after == model.layerReach(gaming))
    }

    @Test("A stored-table re-read drops the memo")
    func storedReadDropsTheMemo() throws {
        let model = try makeModel()
        _ = model.layerReach(layer)
        #expect(model.layerCache != nil)
        let stored = model.ruleReachStored
        model.ruleReachStored = stored
        #expect(model.layerCache == nil)
    }

    @Test("A reading taken with edits of its own leaves the memo alone")
    func explicitEditsBypassTheMemo() throws {
        let model = try makeModel()
        let reading = try #require(model.layerReach(layer))
        let key = model.layerCache?.key
        var edits = model.reachEdits
        edits.layers[layer] = LayerEdit(stored: layer)
        _ = model.layerReach(layer, edits: edits)
        #expect(model.layerCache?.key == key)
        #expect(model.layerCache?.readings[layer] == .some(reading))
    }
}
