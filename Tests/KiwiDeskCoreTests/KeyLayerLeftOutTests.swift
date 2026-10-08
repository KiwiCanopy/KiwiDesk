import Foundation
import Testing

@testable import KiwiDeskCore

/// #2022: a profile may leave a SHARED layer out whole — the
/// per-combo `removed` mark one level up — so the base keeps the
/// layer for every other profile and every later one.
@Suite("Key layer override, left-out layer (#2022)")
struct KeyLayerLeftOutTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .custom, label: lua)
    }

    private var base: [KeyLayer] {
        [
            KeyLayer(name: "default", bindings: [row("alt+g", "a()")]),
            KeyLayer(
                name: "Gaming",
                icon: "gamecontroller",
                bindings: [row("w", "up()")]
            ),
            KeyLayer(name: "Focus", bindings: [row("f", "f()")]),
        ]
    }

    @Test("a left-out layer resolves to nothing, its own rows too")
    func leftOutResolvesAway() {
        let over = KeyLayerOverride(
            layers: [KeyLayer(name: "Gaming", bindings: [row("s", "d()")])],
            leftOut: ["Gaming"]
        )
        #expect(
            over.resolved(onto: base).map(\.name) == ["default", "Focus"]
        )
        #expect(over.overrideCount == 2)
        #expect(!over.isEmpty)
    }

    @Test("a base layer the edit drops is left out, and reads back")
    func diffLeavesTheLayerOut() throws {
        let edited = base.filter { $0.name != "Gaming" }
        let over = try #require(
            KeyLayerOverride.diff(base: base, edited: edited)
        )
        #expect(over.leftOut == ["Gaming"])
        #expect(over.layers.isEmpty)
        #expect(over.resolved(onto: base) == edited)
    }

    @Test("the default layer is never left out")
    func defaultStays() {
        let over = KeyLayerOverride(leftOut: ["default", "Focus", "Focus"])
        #expect(over.leftOut == ["Focus"])
        #expect(over.resolved(onto: base).first?.name == "default")
    }

    @Test("the mark round-trips as `left_out` on its own entry")
    func codableRoundTrip() throws {
        let over = KeyLayerOverride(
            layers: [KeyLayer(name: "default", bindings: [row("x", "x()")])],
            removed: ["Focus": ["f"]],
            leftOut: ["Gaming"]
        )
        let data = try JSONEncoder().encode(over)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"left_out\":true"))
        let back = try JSONDecoder().decode(
            KeyLayerOverride.self,
            from: data
        )
        #expect(back == over)
        // The mark's entry is no diverging layer of its own.
        #expect(back.layers.map(\.name) == ["default"])
    }

    @Test("a profile created later still gets the shared layer")
    func laterProfileGetsIt() {
        let desk = KeyLayerOverride(leftOut: ["Gaming"])
        #expect(!desk.resolved(onto: base).contains { $0.name == "Gaming" })
        let later: KeyLayerOverride? = nil
        #expect(
            ConfigResolver.resolvedLayers(base: base, profile: later)
                .contains { $0.name == "Gaming" }
        )
    }
}
