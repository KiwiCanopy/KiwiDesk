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

    private func table() -> RuleReachTable<GestureAction> {
        .gestures(
            base: base,
            overrides: [("Work", work), ("Home", nil)]
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
                profile: override
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
        #expect(table.gestureBase(original: base) == base)
        #expect(table.gestureOverride(for: "Work") == work)
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
            home?[GestureKey(.rightClick, [.control])] == .bound(.run(tap))
        )
        #expect(table.gestureBase(original: base) == base)
        #expect(table.gestureOverride(for: "Work") == work)
    }

    @Test("a shared row turned off writes a seed's tombstone")
    func sharedRemovalTurnsTheSeedOff() {
        var table = table()
        let key = GestureKey(.drag, [.control, .command])
        table.apply(
            key.spelling,
            value: nil,
            reach: .shared(joining: []),
            editing: "Home"
        )
        let written = table.gestureBase(original: base)
        #expect(written[key] == .unbound)
        #expect(written[GestureKey(.tap3)] == .unbound)
    }

    @Test("a profile page overlays the profile's own entries")
    func overlayIsTheProfile() {
        let page = base.overlaid(by: work)
        #expect(
            GestureSeeds.resolved(base: page, profile: nil)
                == GestureSeeds.resolved(base: base, profile: work)
        )
    }
}
