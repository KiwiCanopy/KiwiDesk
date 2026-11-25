import Foundation
import Testing

@testable import KiwiDeskCore

/// The gesture bindings as a rule-reach family (#3225): the table
/// resolves what the runtime resolves, re-encodes the files it read
/// unchanged, and writes a reached profile's own map.
@Suite("Gesture reach table")
struct GestureReachTableTests {
    private let pan = GestureSeeds.panKeys
    private let tap = LuaAction(lua: "KiwiDesk.reload_config()", kind: .custom)

    private var base: GestureMap {
        var map = GestureMap()
        map[GestureKey(.tap3)] = .unbound
        map[GestureKey(.click, [.option])] = .bound(.run(tap))
        return map
    }

    private var work: GestureMap {
        var map = GestureMap()
        map[GestureKey(.tap4)] = .unbound
        map[GestureKey(.click, [.option])] = .unbound
        map[GestureKey(.swipe2, pan)] = .bound(.family(.space))
        return map
    }

    private func layered(_ map: GestureMap) -> LayerGestures {
        LayerGestures(defaultLayer: map)
    }

    /// Another layer's rows key apart from default's, lie over no
    /// seeds and write back to that layer's map (#3535).
    @Test("a layer's rows key apart and write to their layer")
    func layerRows() {
        let coding = GestureMap([GestureKey(.tap3): .bound(.run(tap))])
        let maps = LayerGestures(["default": base, "Coding": coding])
        var table = RuleReachTable<GestureAction>.gestures(
            base: maps,
            overrides: [("Work", nil)],
            shortcutBase: .standard
        )
        let key = LayerGestureKey("Coding", GestureKey(.tap3)).spelling
        #expect(table.resolved(key, for: "Work") == .run(tap))
        #expect(
            table.resolved(GestureKey(.tap3).spelling, for: "Work") == nil
        )
        #expect(
            table.gestureBase(original: maps, shortcutBase: .standard) == maps
        )
        table.apply(
            key,
            value: nil,
            reach: .shared(joining: []),
            editing: "Work"
        )
        let written = table.gestureBase(
            original: maps,
            shortcutBase: .standard
        )
        // No seed sits under Coding's tap, so nothing is tombstoned.
        #expect(written["Coding"].isEmpty)
        #expect(written["default"] == base)
    }

    /// A layer's binding equal to a default seed is kept: only
    /// `default` lies over the seeds (#3535 ▸ Ruling 1).
    @Test("a layer keeps a binding a default seed shares")
    func layerKeepsASeedValue() throws {
        let (seed, action) = try #require(
            GestureSeeds.seeds(on: .standard).first
        )
        var table = RuleReachTable<GestureAction>.gestures(
            base: LayerGestures(),
            overrides: [("Work", nil)],
            shortcutBase: .standard
        )
        table.apply(
            LayerGestureKey("Coding", seed).spelling,
            value: action,
            reach: .shared(joining: []),
            editing: "Work"
        )
        let written = table.gestureBase(
            original: LayerGestures(),
            shortcutBase: .standard
        )
        #expect(written["Coding"][seed] == .bound(action))
    }

    private func table() -> RuleReachTable<GestureAction> {
        .gestures(
            base: LayerGestures(defaultLayer: base),
            overrides: [
                ("Work", LayerGestures(defaultLayer: work)), ("Home", nil),
            ],
            shortcutBase: .standard
        )
    }

    /// Over a fixture with no refused or drag-held key, which the
    /// table keeps as stored (`RuleReach+Gesture`).
    @Test("each profile resolves what the runtime resolves")
    func resolvesLikeTheRuntime() {
        let table = table()
        for (name, override) in [("Work", work), ("Home", nil)] {
            let runtime = GestureSeeds.resolved(
                base: base,
                profile: override,
                shortcutBase: .standard,
                layer: KeyLayer.defaultName
            )
            let resolved = table.resolved(for: name).compactMap { pair in
                GestureKey(spelling: pair.key).map { ($0, pair.value) }
            }
            #expect(!resolved.isEmpty)
            #expect(Dictionary(uniqueKeysWithValues: resolved) == runtime)
        }
    }

    @Test("an untouched table writes back the files it read")
    func untouchedIsLossless() {
        let table = table()
        #expect(
            table.gestureBase(original: layered(base), shortcutBase: .standard)
                == layered(base)
        )
        #expect(table.gestureOverride(for: "Work") == layered(work))
        #expect(table.gestureOverride(for: "Home") == nil)
    }

    @Test("a profile's tombstone reads as leaving the key out")
    func tombstoneIsLeftOut() {
        let table = table()
        let tap4 = GestureKey(.tap4).spelling
        #expect(table.leftOut(tap4) == ["Work"])
        #expect(table.resolved(tap4, for: "Home") != nil)
    }

    @Test("a row listed for one profile lands in its file alone")
    func listedWritesTheProfile() {
        var table = table()
        let key = GestureKey(.rightClick, [.control]).spelling
        table.apply(
            key,
            value: .run(tap),
            reach: .listed(["Home"]),
            editing: "Home"
        )
        let home = table.gestureOverride(for: "Home")
        #expect(
            home?["default"][GestureKey(.rightClick, [.control])]
                == .bound(.run(tap))
        )
        #expect(
            table.gestureBase(original: layered(base), shortcutBase: .standard)
                == layered(base)
        )
        #expect(table.gestureOverride(for: "Work") == layered(work))
    }

    @Test("a shared row turned off writes a seed's tombstone")
    func sharedRemovalTurnsTheSeedOff() {
        var table = table()
        let key = GestureKey(.drag, [.control, .option])
        table.apply(
            key.spelling,
            value: nil,
            reach: .shared(joining: []),
            editing: "Home"
        )
        let written = table.gestureBase(
            original: layered(base),
            shortcutBase: .standard
        )["default"]
        #expect(written[key] == .unbound)
        #expect(written[GestureKey(.tap3)] == .unbound)
    }

    @Test("a profile page overlays the profile's own entries")
    func overlayIsTheProfile() {
        let page = base.overlaid(by: work)
        #expect(
            GestureSeeds.resolved(
                base: page,
                profile: nil,
                shortcutBase: .standard,
                layer: KeyLayer.defaultName
            )
                == GestureSeeds.resolved(
                    base: base,
                    profile: work,
                    shortcutBase: .standard,
                    layer: KeyLayer.defaultName
                )
        )
    }
}
