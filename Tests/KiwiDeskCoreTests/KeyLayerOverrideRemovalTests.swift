import Foundation
import Testing

@testable import KiwiDeskCore

/// A shortcut override's removed combos (#1393): the "left out
/// here" a profile needs to drop or move a shared shortcut, stored
/// beside the layer rows it rides with.
@Suite("KeyLayerOverride — removed combos (#1393)")
struct KeyLayerOverrideRemovalTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .custom, label: "")
    }

    private var base: [KeyLayer] {
        [
            KeyLayer(
                name: "default",
                bindings: [row("alt+t", "terminal"), row("alt+r", "reload")]
            ),
            KeyLayer(
                name: "resize",
                icon: "📐",
                bindings: [row("alt+l", "grow")]
            ),
        ]
    }

    private func roundTrip(_ over: KeyLayerOverride) throws
        -> KeyLayerOverride
    {
        try JSONDecoder().decode(
            KeyLayerOverride.self,
            from: JSONEncoder().encode(over)
        )
    }

    @Test("A removed combo drops its base row on resolve")
    func removedDropsRow() {
        let over = KeyLayerOverride(removed: ["default": ["alt+t"]])
        let resolved = over.resolved(onto: base)
        #expect(resolved[0].bindings.map(\.combo) == ["alt+r"])
        #expect(resolved[1] == base[1])
    }

    @Test("A removed combo and a row on another combo resolve together")
    func removedBesideRow() {
        let over = KeyLayerOverride(
            layers: [
                KeyLayer(name: "default", bindings: [row("alt+y", "terminal")])
            ],
            removed: ["default": ["alt+t"]]
        )
        let combos = over.resolved(onto: base)[0].bindings.map(\.combo)
        #expect(combos == ["alt+r", "alt+y"])
    }

    @Test("A removal the base no longer holds is inert")
    func staleRemovalInert() {
        let over = KeyLayerOverride(
            removed: ["default": ["alt+q"], "gone": ["alt+g"]]
        )
        #expect(over.resolved(onto: base) == base)
        // And the next diff drops it, so a stale mark never persists.
        #expect(
            KeyLayerOverride.diff(
                base: base,
                edited: over.resolved(onto: base)
            ) == nil
        )
    }

    @Test("Removals count and make the override non-empty")
    func removalsCount() {
        let over = KeyLayerOverride(removed: ["default": ["alt+t", "alt+r"]])
        #expect(!over.isEmpty)
        #expect(over.overrideCount == 2)
        #expect(KeyLayerOverride(removed: ["default": []]).isEmpty)
    }

    @Test("Removals round-trip beside rows and on their own")
    func codecRoundTrip() throws {
        let over = KeyLayerOverride(
            layers: [
                KeyLayer(name: "default", bindings: [row("alt+y", "terminal")])
            ],
            removed: ["default": ["alt+t"], "resize": ["alt+l"]]
        )
        let back = try roundTrip(over)
        #expect(back == over)
        #expect(back.resolved(onto: base) == over.resolved(onto: base))
    }

    @Test("A removal-only entry is stored in the layer array")
    func removalOnlyShape() throws {
        let data = try JSONEncoder().encode(
            KeyLayerOverride(removed: ["resize": ["alt+l"]])
        )
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )
        #expect(json.count == 1)
        #expect(json[0]["name"] as? String == "resize")
        #expect(json[0]["removed"] as? [String] == ["alt+l"])
        // No diverging layer of its own: the icon stays the base's.
        let back = try JSONDecoder().decode(KeyLayerOverride.self, from: data)
        #expect(back.layers.isEmpty)
        #expect(back.resolved(onto: base)[1].icon == "📐")
    }

    @Test("An override stored before removals decodes with none")
    func legacyShapeDecodes() throws {
        let data = Data(
            #"[{"name":"default","bindings":[{"combo":"alt+t","lua":"x"}]}]"#
                .utf8
        )
        let over = try JSONDecoder().decode(KeyLayerOverride.self, from: data)
        #expect(over.removed.isEmpty)
        #expect(over.layers.map(\.name) == ["default"])
    }

    @Test("A profile carrying removals survives its own file")
    func profileRoundTrip() throws {
        var profile = Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["m"])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
        profile.layers = KeyLayerOverride(removed: ["default": ["alt+t"]])
        let back = try JSONDecoder().decode(
            Profile.self,
            from: JSONEncoder().encode(profile)
        )
        #expect(back.layers == profile.layers)
    }
}
