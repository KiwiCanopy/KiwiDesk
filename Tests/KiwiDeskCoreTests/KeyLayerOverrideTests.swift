import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Test helpers

private func binding(
    combo: String,
    lua: String = "-- noop",
    label: String = ""
) -> KeyBinding {
    KeyBinding(
        combo: combo,
        lua: lua,
        kind: .custom,
        label: label
    )
}

private func layer(
    _ name: String,
    icon: String? = nil,
    combos: [(String, String)] = []
) -> KeyLayer {
    KeyLayer(
        name: name,
        icon: icon,
        bindings: combos.map { binding(combo: $0.0, lua: $0.1) }
    )
}

// MARK: - KeyLayerOverride tests

/// `KeyLayerOverride` is a keyed collection merge (layer name ×
/// combo), NOT a struct field-mirror — so no reflection parity
/// net applies. Guarded by: round-trip, resolve-every-case, and
/// default-layer-invariant tests (AGENTS.md §5).
@Suite("KeyLayerOverride — data model and merge (#55)")
struct KeyLayerOverrideTests {

    // MARK: - isEmpty / init

    @Test("Empty override reports isEmpty")
    func emptyIsEmpty() {
        #expect(KeyLayerOverride().isEmpty)
        #expect(KeyLayerOverride(layers: []).isEmpty)
    }

    @Test("Non-empty override is not empty")
    func nonEmpty() {
        let over = KeyLayerOverride(
            layers: [layer("default", combos: [("alt+h", "")])]
        )
        #expect(!over.isEmpty)
    }

    // MARK: - Round-trip

    @Test("Round-trip: encode then decode equals original")
    func roundTrip() throws {
        let over = KeyLayerOverride(
            layers: [
                layer("default", combos: [("alt+h", "focus()")]),
                layer(
                    "resize",
                    icon: "📐",
                    combos: [("alt+l", "resize()")]
                ),
            ]
        )
        let data = try JSONEncoder().encode(over)
        let back = try JSONDecoder().decode(
            KeyLayerOverride.self,
            from: data
        )
        #expect(back == over)
    }

    // MARK: - Sparse encoding (O3)

    @Test("Empty override encodes as bare empty array, not null")
    func emptyEncodesAsBareArray() throws {
        let data = try JSONEncoder().encode(KeyLayerOverride())
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        #expect(json == "[]")
    }

    @Test("Non-empty override encodes as bare array of layers")
    func nonEmptyEncodesAsBareArray() throws {
        let over = KeyLayerOverride(
            layers: [layer("default", combos: [("alt+h", "")])]
        )
        let data = try JSONEncoder().encode(over)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        // Must be a bare array, not {"layers": [...]}
        #expect(json.hasPrefix("["))
        #expect(json.contains("\"default\""))
    }

    // MARK: - resolved(onto:) merge semantics

    @Test("Empty override leaves base unchanged")
    func emptyResolvedLeavesBase() {
        let base = [
            layer("default", combos: [("alt+h", "focus")])
        ]
        #expect(KeyLayerOverride().resolved(onto: base) == base)
    }

    @Test("Override combo wins; unmentioned base combos survive")
    func overrideComboWins() {
        let base = [
            layer(
                "default",
                combos: [
                    ("alt+h", "focus_left"),
                    ("alt+j", "focus_down"),
                ]
            )
        ]
        let over = KeyLayerOverride(
            layers: [
                layer("default", combos: [("alt+h", "CUSTOM")])
            ]
        )
        let result = over.resolved(onto: base)
        #expect(result.count == 1)
        let bindings = result[0].bindings
        // Override wins for alt+h.
        let h = bindings.first { $0.combo == "alt+h" }
        #expect(h?.lua == "CUSTOM")
        // Unmentioned alt+j survives from base.
        let j = bindings.first { $0.combo == "alt+j" }
        #expect(j?.lua == "focus_down")
        // In-place merge: base row order survives (the GUI
        // renders resolved layers — rows must not jump).
        #expect(bindings.map(\.combo) == ["alt+h", "alt+j"])
    }

    @Test("Duplicate base combo: override wins over every copy")
    func duplicateBaseComboOverridden() {
        // Hand-edited gui.json can carry a duplicate combo;
        // decode does not validate. Every copy must take the
        // override — registration is last-wins, so a stale
        // trailing base row would silently displace it.
        let base = [
            layer(
                "default",
                combos: [
                    ("alt+h", "first"),
                    ("alt+j", "keep"),
                    ("alt+h", "second"),
                ]
            )
        ]
        let over = KeyLayerOverride(
            layers: [layer("default", combos: [("alt+h", "WIN")])]
        )
        let result = over.resolved(onto: base)
        let hRows = result[0].bindings.filter {
            $0.combo == "alt+h"
        }
        #expect(!hRows.isEmpty)
        #expect(hRows.allSatisfy { $0.lua == "WIN" })
        // The unrelated row is untouched.
        let j = result[0].bindings.first { $0.combo == "alt+j" }
        #expect(j?.lua == "keep")
    }

    @Test("Override icon replaces base icon when non-nil")
    func iconOverride() {
        let base = [
            layer(
                "resize",
                icon: "🔧",
                combos: [("alt+h", "")]
            )
        ]
        let over = KeyLayerOverride(
            layers: [layer("resize", icon: "📐")]
        )
        let result = over.resolved(onto: base)
        #expect(result[0].icon == "📐")
    }

    @Test("Nil override icon keeps base icon")
    func nilIconKeepsBase() {
        let base = [
            layer(
                "resize",
                icon: "🔧",
                combos: [("alt+h", "")]
            )
        ]
        // Override has no icon (nil).
        let over = KeyLayerOverride(
            layers: [layer("resize")]
        )
        let result = over.resolved(onto: base)
        #expect(result[0].icon == "🔧")
    }

    @Test("Override layer absent from base is appended")
    func newModeAppended() {
        let base = [
            layer("default", combos: [("alt+h", "focus")])
        ]
        let over = KeyLayerOverride(
            layers: [
                layer("custom", combos: [("alt+x", "noop")])
            ]
        )
        let result = over.resolved(onto: base)
        #expect(result.count == 2)
        #expect(result[0].name == "default")
        #expect(result[1].name == "custom")
        #expect(result[1].bindings[0].combo == "alt+x")
    }

    @Test("Base layer absent from override passes through")
    func baseModeSurvives() {
        let base = [
            layer("default", combos: [("alt+h", "focus")]),
            layer("other", combos: [("alt+y", "swap")]),
        ]
        // Override only touches "default".
        let over = KeyLayerOverride(
            layers: [layer("default", combos: [("alt+h", "X")])]
        )
        let result = over.resolved(onto: base)
        #expect(result.count == 2)
        // "other" layer is preserved exactly.
        #expect(result[1].name == "other")
        #expect(result[1].bindings[0].combo == "alt+y")
        #expect(result[1].bindings[0].lua == "swap")
    }

    // MARK: - Default-layer invariant (O4 switch-key-trap)

    /// A profile that rebinds exactly one combo in the default
    /// layer must still expose every other base binding — the
    /// O4 soft base layer guarantees no switch-key trap.
    @Test("Default-layer invariant: unbound base combos survive")
    func defaultLayerInvariant() {
        let switchKey = binding(
            combo: "alt+p",
            lua: "load_profile(\"Work\")"
        )
        let base = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    switchKey,
                    binding(combo: "alt+h", lua: "focus_left"),
                    binding(combo: "alt+j", lua: "focus_down"),
                ]
            )
        ]
        // Profile rebinds only alt+h.
        let over = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [
                        binding(combo: "alt+h", lua: "CUSTOM")
                    ]
                )
            ]
        )
        let result = over.resolved(onto: base)
        #expect(result.count == 1)
        let combos = result[0].bindings.map(\.combo)
        // alt+p (switch key) must survive — no trap.
        #expect(combos.contains("alt+p"))
        // alt+j must also survive.
        #expect(combos.contains("alt+j"))
        // alt+h is overridden.
        let h = result[0].bindings.first { $0.combo == "alt+h" }
        #expect(h?.lua == "CUSTOM")
    }
}
