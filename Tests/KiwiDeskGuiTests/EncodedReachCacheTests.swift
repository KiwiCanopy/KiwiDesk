import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// `encodedReach` is memoized: every shortcut row read it several
/// times per render, and a Desktop switch re-rendered them all —
/// about 650 ms of one switch's main turn with the Shortcuts page
/// open (device sample, 2026-10-10). A memo is only safe while each
/// input it reads moves it, so each case changes ONE input after a
/// read and requires the next read to see it.
@Suite("The draft's reach encode is memoized safely", .serialized)
@MainActor
struct EncodedReachCacheTests {
    private let focus = "KiwiDesk.focus(\"left\")"
    private let reload = "KiwiDesk.reload_config()"

    /// gui.json binds focus left; Work is loaded, Home stored.
    private func makeModel(_ extra: [KeyBinding] = []) throws
        -> SettingsModel
    {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "alt+h", lua: focus, kind: .navigation)
                ] + extra
            )
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

    private func key(_ lua: String) -> String {
        RuleReachTable<String>.keyID(layer: KeyLayer.defaultName, lua: lua)
    }

    @Test("A read fills the memo and a second read reuses it")
    func readFillsTheMemo() throws {
        let model = try makeModel()
        let first = try #require(model.encodedReach)
        let cached = try #require(model.encodedCache)
        #expect(model.encodedReach == first)
        #expect(model.encodedCache?.key == cached.key)
    }

    @Test("A page edit after a read is seen by the next read")
    func pageEditMovesTheMemo() throws {
        let model = try makeModel()
        let before = try #require(model.encodedReach)
        model.config.layers[0].bindings.append(
            KeyBinding(combo: "ctrl+alt+r", lua: reload, kind: .custom)
        )
        let after = try #require(model.encodedReach)
        #expect(after != before)
        #expect(after == model.encodeReach())
    }

    @Test("A checklist pick after a read is seen by the next read")
    func pickMovesTheMemo() throws {
        let model = try makeModel()
        model.config.layers[0].bindings.append(
            KeyBinding(combo: "ctrl+alt+r", lua: reload, kind: .custom)
        )
        let before = try #require(model.encodedReach)
        model.reachEdits.reach[.key, default: [:]][key(reload)] =
            .listed(["Work", "Home"])
        let after = try #require(model.encodedReach)
        #expect(after != before)
        #expect(after == model.encodeReach())
    }

    @Test("The rivals are built once per encode, from its table")
    func rivalsFollowTheEncode() throws {
        let model = try makeModel()
        let first = try #require(model.encodedKeyRivals)
        #expect(model.encodedCache?.rivals == first)
        model.config.layers[0].bindings.append(
            KeyBinding(combo: "alt+h", lua: reload, kind: .custom)
        )
        // The new encode starts with no rivals of its own.
        let table = try #require(model.encodedReach?.keyLayers)
        #expect(model.encodedCache?.rivals == nil)
        let after = try #require(model.encodedKeyRivals)
        #expect(after == KeyRivals(table))
        #expect(model.encodedCache?.rivals == after)
    }

    @Test("A stored-table re-read drops the memo")
    func storedReadDropsTheMemo() throws {
        let model = try makeModel()
        _ = model.encodedReach
        #expect(model.encodedCache != nil)
        let stored = model.ruleReachStored
        model.ruleReachStored = stored
        #expect(model.encodedCache == nil)
    }

    /// Rivals from a table where reload holds focus's combo too.
    private func plantedRivals() throws -> KeyRivals {
        let other = try makeModel([
            KeyBinding(combo: "alt+h", lua: reload, kind: .custom)
        ])
        return try #require(other.encodedKeyRivals)
    }

    @Test("A read takes the stored rivals, and a row's takers follow them")
    func rivalsAreReadFromTheMemo() throws {
        let model = try makeModel()
        let planted = try plantedRivals()
        _ = model.encodedReach
        #expect(model.encodedKeyRivals != planted)
        #expect(model.keyReach(key(focus))?.takenBy["Home"] == nil)
        model.encodedCache?.rivals = planted
        #expect(model.encodedKeyRivals == planted)
        #expect(model.keyReach(key(focus))?.takenBy["Home"] != nil)
    }
}
