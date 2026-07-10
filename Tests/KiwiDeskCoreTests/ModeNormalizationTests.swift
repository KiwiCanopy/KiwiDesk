import Foundation
import Testing

@testable import KiwiDeskCore

/// Decode-time normalization of untrusted mode lists (#31):
/// duplicate names, a default-mode icon, and empty names are
/// cleaned predictably at the two JSON boundaries —
/// `GuiConfig.modes` (full list) and `KeyModeOverride`
/// (sparse override). One shared helper serves both.
@Suite("Mode list normalization (#31)")
struct ModeNormalizationTests {

    private func mode(
        _ name: String,
        icon: String? = nil,
        combo: String? = nil
    ) -> KeyMode {
        KeyMode(
            name: name,
            icon: icon,
            bindings: combo.map {
                [KeyBinding(combo: $0, lua: "-- noop")]
            } ?? []
        )
    }

    // MARK: - Shared core (via the full flavor)

    @Test("Duplicate mode names: first occurrence wins")
    func duplicateNamesFirstWins() {
        let result = KeyMode.normalized(full: [
            mode("default"),
            mode("resize", combo: "alt+r"),
            mode("resize", combo: "alt+x"),
        ])
        #expect(result.map(\.name) == ["default", "resize"])
        #expect(result[1].bindings.first?.combo == "alt+r")
    }

    @Test("Second 'default' entry is dropped, its icon lost")
    func duplicateDefaultDropped() {
        let result = KeyMode.normalized(full: [
            mode("default", combo: "alt+h"),
            mode("default", icon: "gear"),
        ])
        #expect(result.count == 1)
        #expect(result[0].isDefault)
        #expect(result[0].icon == nil)
        #expect(result[0].bindings.first?.combo == "alt+h")
    }

    @Test("Icon on the default mode is stripped")
    func defaultIconStripped() {
        let result = KeyMode.normalized(full: [
            mode("default", icon: "gear"),
            mode("resize", icon: "arrow.left.and.right"),
        ])
        #expect(result[0].icon == nil)
        // Non-default modes keep their icon untouched.
        #expect(result[1].icon == "arrow.left.and.right")
    }

    @Test("Empty-named modes are dropped")
    func emptyNamesDropped() {
        let result = KeyMode.normalized(full: [
            mode("default"),
            mode("", combo: "alt+z"),
        ])
        #expect(result.map(\.name) == ["default"])
    }

    @Test("Valid input passes through untouched")
    func validInputUntouched() {
        let modes = [
            mode("default", combo: "alt+h"),
            mode("resize", icon: "📐", combo: "alt+r"),
        ]
        #expect(KeyMode.normalized(full: modes) == modes)
        #expect(KeyMode.normalized(sparse: modes) == modes)
    }

    // MARK: - Full flavor (GuiConfig.modes)

    @Test("Empty list falls back to [KeyMode.defaultMode]")
    func emptyFallsBackToDefault() {
        let result = KeyMode.normalized(full: [])
        #expect(result == [KeyMode.defaultMode])
    }

    @Test("Missing default mode is inserted first")
    func missingDefaultInserted() {
        let result = KeyMode.normalized(full: [
            mode("resize", combo: "alt+r")
        ])
        #expect(result.map(\.name) == ["default", "resize"])
    }

    @Test("A default mode not first is moved to the front")
    func defaultMovedToFront() {
        let result = KeyMode.normalized(full: [
            mode("resize", combo: "alt+r"),
            mode("default", combo: "alt+h"),
        ])
        #expect(result.map(\.name) == ["default", "resize"])
        #expect(result[0].bindings.first?.combo == "alt+h")
    }

    @Test("Whitespace-only names are dropped like empty ones")
    func whitespaceNamesDropped() {
        let result = KeyMode.normalized(full: [
            mode("default"),
            mode("  ", combo: "alt+z"),
        ])
        #expect(result.map(\.name) == ["default"])
    }

    @Test("Composite: later default dropped, first moved front")
    func duplicateDefaultNotFirstComposite() {
        // The review's worst case in one input: the FIRST
        // default wins (keeps alt+h, later bindings are
        // dropped with their entry), then moves to the front.
        let result = KeyMode.normalized(full: [
            mode("resize", combo: "alt+r"),
            mode("default", combo: "alt+h"),
            mode("default", icon: "gear", combo: "alt+z"),
        ])
        #expect(result.map(\.name) == ["default", "resize"])
        #expect(result[0].bindings.map(\.combo) == ["alt+h"])
        #expect(result[0].icon == nil)
    }

    // MARK: - Sparse flavor (KeyModeOverride)

    @Test("Sparse: no default entry is inserted")
    func sparseInsertsNoDefault() {
        let result = KeyMode.normalized(sparse: [
            mode("resize", combo: "alt+r")
        ])
        #expect(result.map(\.name) == ["resize"])
        #expect(KeyMode.normalized(sparse: []).isEmpty)
    }

    @Test("Sparse: duplicates dropped, default icon stripped")
    func sparseSanitizes() {
        let result = KeyMode.normalized(sparse: [
            mode("resize", combo: "alt+r"),
            mode("default", icon: "gear"),
            mode("resize", combo: "alt+x"),
        ])
        // Order preserved as stored — never reordered.
        #expect(result.map(\.name) == ["resize", "default"])
        #expect(result[0].bindings.first?.combo == "alt+r")
        #expect(result[1].icon == nil)
    }
}

/// The normalization applied at the real decode boundaries:
/// hand-edited JSON through `GuiConfig` and `KeyModeOverride`.
@Suite("Mode normalization at the decode boundaries (#31)")
struct ModeNormalizationDecodeTests {

    @Test("GuiConfig decode normalizes a hand-edited sidecar")
    func guiConfigDecodeNormalizes() throws {
        let json = """
            {"modes":[
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
            config.modes.map(\.name) == ["default", "resize"]
        )
        #expect(config.modes[0].icon == nil)
    }

    @Test("GuiConfig decode: empty modes fall back to default")
    func guiConfigEmptyModesFallBack() throws {
        for json in ["{}", "{\"modes\":[]}"] {
            let config = try JSONDecoder().decode(
                GuiConfig.self,
                from: Data(json.utf8)
            )
            #expect(config.modes == [KeyMode.defaultMode])
        }
    }

    @Test("GuiConfig round-trip stays normalized")
    func guiConfigRoundTripStaysNormalized() throws {
        let json = """
            {"modes":[
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
        #expect(second.modes == first.modes)
        #expect(second.modes == [KeyMode.defaultMode])
    }

    @Test("KeyModeOverride decode normalizes, stays sparse")
    func overrideDecodeNormalizes() throws {
        let json = """
            [
              {"name":"resize","bindings":[]},
              {"name":"resize","icon":"x","bindings":[]},
              {"name":"default","icon":"gear","bindings":[]}
            ]
            """
        let over = try JSONDecoder().decode(
            KeyModeOverride.self,
            from: Data(json.utf8)
        )
        #expect(
            over.modes.map(\.name) == ["resize", "default"]
        )
        #expect(over.modes[1].icon == nil)
        // Resolving onto a base never gives default an icon.
        let resolved = over.resolved(
            onto: [KeyMode.defaultMode]
        )
        let def = resolved.first { $0.isDefault }
        #expect(def?.icon == nil)
    }
}
