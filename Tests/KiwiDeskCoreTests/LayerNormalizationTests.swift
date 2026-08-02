import Foundation
import Testing

@testable import KiwiDeskCore

/// Decode-time normalization of untrusted layer lists (#31):
/// duplicate names, a default-layer icon, and empty names are
/// cleaned predictably at the two JSON boundaries —
/// `GuiConfig.layers` (full list) and `KeyLayerOverride`
/// (sparse override). One shared helper serves both.
@Suite("Mode list normalization (#31)")
struct ModeNormalizationTests {

    private func layer(
        _ name: String,
        icon: String? = nil,
        combo: String? = nil
    ) -> KeyLayer {
        KeyLayer(
            name: name,
            icon: icon,
            bindings: combo.map {
                [KeyBinding(combo: $0, lua: "-- noop")]
            } ?? []
        )
    }

    // MARK: - Shared core (via the full flavor)

    @Test("Duplicate layer names: first occurrence wins")
    func duplicateNamesFirstWins() {
        let result = KeyLayer.normalized(full: [
            layer("default"),
            layer("resize", combo: "alt+r"),
            layer("resize", combo: "alt+x"),
        ])
        #expect(result.map(\.name) == ["default", "resize"])
        #expect(result[1].bindings.first?.combo == "alt+r")
    }

    @Test("Second 'default' entry is dropped, its icon lost")
    func duplicateDefaultDropped() {
        let result = KeyLayer.normalized(full: [
            layer("default", combo: "alt+h"),
            layer("default", icon: "gear"),
        ])
        #expect(result.count == 1)
        #expect(result[0].isDefault)
        #expect(result[0].icon == nil)
        #expect(result[0].bindings.first?.combo == "alt+h")
    }

    @Test("Icon on the default layer is stripped")
    func defaultIconStripped() {
        let result = KeyLayer.normalized(full: [
            layer("default", icon: "gear"),
            layer("resize", icon: "arrow.left.and.right"),
        ])
        #expect(result[0].icon == nil)
        // Non-default layers keep their icon untouched.
        #expect(result[1].icon == "arrow.left.and.right")
    }

    @Test("Empty-named layers are dropped")
    func emptyNamesDropped() {
        let result = KeyLayer.normalized(full: [
            layer("default"),
            layer("", combo: "alt+z"),
        ])
        #expect(result.map(\.name) == ["default"])
    }

    @Test("Valid input passes through untouched")
    func validInputUntouched() {
        let layers = [
            layer("default", combo: "alt+h"),
            layer("resize", icon: "📐", combo: "alt+r"),
        ]
        #expect(KeyLayer.normalized(full: layers) == layers)
        #expect(KeyLayer.normalized(sparse: layers) == layers)
    }

    // MARK: - Full flavor (GuiConfig.layers)

    @Test("Empty list falls back to [KeyLayer.defaultLayer]")
    func emptyFallsBackToDefault() {
        let result = KeyLayer.normalized(full: [])
        #expect(result == [KeyLayer.defaultLayer])
    }

    @Test("Missing default layer is inserted first")
    func missingDefaultInserted() {
        let result = KeyLayer.normalized(full: [
            layer("resize", combo: "alt+r")
        ])
        #expect(result.map(\.name) == ["default", "resize"])
    }

    @Test("A default layer not first is moved to the front")
    func defaultMovedToFront() {
        let result = KeyLayer.normalized(full: [
            layer("resize", combo: "alt+r"),
            layer("default", combo: "alt+h"),
        ])
        #expect(result.map(\.name) == ["default", "resize"])
        #expect(result[0].bindings.first?.combo == "alt+h")
    }

    @Test("Whitespace-only names are dropped like empty ones")
    func whitespaceNamesDropped() {
        let result = KeyLayer.normalized(full: [
            layer("default"),
            layer("  ", combo: "alt+z"),
        ])
        #expect(result.map(\.name) == ["default"])
    }

    @Test("Composite: later default dropped, first moved front")
    func duplicateDefaultNotFirstComposite() {
        // The review's worst case in one input: the FIRST
        // default wins (keeps alt+h, later bindings are
        // dropped with their entry), then moves to the front.
        let result = KeyLayer.normalized(full: [
            layer("resize", combo: "alt+r"),
            layer("default", combo: "alt+h"),
            layer("default", icon: "gear", combo: "alt+z"),
        ])
        #expect(result.map(\.name) == ["default", "resize"])
        #expect(result[0].bindings.map(\.combo) == ["alt+h"])
        #expect(result[0].icon == nil)
    }

    // MARK: - Sparse flavor (KeyLayerOverride)

    @Test("Sparse: no default entry is inserted")
    func sparseInsertsNoDefault() {
        let result = KeyLayer.normalized(sparse: [
            layer("resize", combo: "alt+r")
        ])
        #expect(result.map(\.name) == ["resize"])
        #expect(KeyLayer.normalized(sparse: []).isEmpty)
    }

    @Test("Sparse: duplicates dropped, default icon stripped")
    func sparseSanitizes() {
        let result = KeyLayer.normalized(sparse: [
            layer("resize", combo: "alt+r"),
            layer("default", icon: "gear"),
            layer("resize", combo: "alt+x"),
        ])
        // Order preserved as stored — never reordered.
        #expect(result.map(\.name) == ["resize", "default"])
        #expect(result[0].bindings.first?.combo == "alt+r")
        #expect(result[1].icon == nil)
    }
}

/// The normalization applied at the real decode boundaries:
/// hand-edited JSON through `GuiConfig` and `KeyLayerOverride`.
@Suite("Mode normalization at the decode boundaries (#31)")
struct ModeNormalizationDecodeTests {

    @Test("GuiConfig decode normalizes a hand-edited sidecar")
    func guiConfigDecodeNormalizes() throws {
        let json = """
            {"layers":[
              {"name":"resize","bindings":[]},
              {"name":"default","icon":"gear","bindings":[]},
              {"name":"resize","bindings":[]},
              {"name":"","bindings":[]}
            ]}
            """
        let config = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(json.utf8)
        )
        #expect(
            config.layers.map(\.name) == ["default", "resize"]
        )
        #expect(config.layers[0].icon == nil)
    }

    @Test("GuiConfig decode: empty layers fall back to default")
    func guiConfigEmptyModesFallBack() throws {
        for json in ["{}", "{\"layers\":[]}"] {
            let config = try JSONDecoder().decode(
                GuiConfig.self,
                from: Data(json.utf8)
            )
            #expect(config.layers == [KeyLayer.defaultLayer])
        }
    }

    @Test("GuiConfig round-trip stays normalized")
    func guiConfigRoundTripStaysNormalized() throws {
        let json = """
            {"layers":[
              {"name":"default","icon":"gear","bindings":[]},
              {"name":"default","bindings":[]}
            ]}
            """
        let first = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(json.utf8)
        )
        let data = try JSONEncoder().encode(first)
        let second = try JSONDecoder().decode(
            GuiConfig.self,
            from: data
        )
        #expect(second.layers == first.layers)
        #expect(second.layers == [KeyLayer.defaultLayer])
    }

    @Test("KeyLayerOverride decode normalizes, stays sparse")
    func overrideDecodeNormalizes() throws {
        let json = """
            [
              {"name":"resize","bindings":[]},
              {"name":"resize","icon":"x","bindings":[]},
              {"name":"default","icon":"gear","bindings":[]}
            ]
            """
        let over = try JSONDecoder().decode(
            KeyLayerOverride.self,
            from: Data(json.utf8)
        )
        #expect(
            over.layers.map(\.name) == ["resize", "default"]
        )
        #expect(over.layers[1].icon == nil)
        // Resolving onto a base never gives default an icon.
        let resolved = over.resolved(
            onto: [KeyLayer.defaultLayer]
        )
        let def = resolved.first { $0.isDefault }
        #expect(def?.icon == nil)
    }
}
