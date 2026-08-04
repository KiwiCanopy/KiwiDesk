import Foundation
import Testing

@testable import KiwiDeskCore

/// `KeyLayerOverride.overrideCount` (#678 turn 13a) — what a
/// profile row means by "N shortcut overrides".
///
/// Its own file rather than an addition to
/// `KeyLayerOverrideTests`, which is near the size ceiling
/// (tests.md: split early).
///
/// The invariant that matters is `isEmpty == (overrideCount ==
/// 0)`. Summing `bindings` alone breaks it: `diff` emits a layer
/// with NO bindings when only its icon diverges, so a profile
/// that overrides something counts zero, the GUI drops the
/// segment, and the row tells the user the profile owns nothing
/// here — the one reading the count exists to prevent.
@Suite("KeyLayerOverride count")
struct KeyLayerOverrideCountTests {
    private func binding(_ combo: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: "KiwiDesk.focus('east')")
    }

    @Test("an empty override counts nothing")
    func emptyCountsZero() {
        #expect(KeyLayerOverride().overrideCount == 0)
        #expect(KeyLayerOverride().isEmpty)
    }

    @Test("each overridden binding counts once")
    func bindingsCount() {
        let over = KeyLayerOverride(layers: [
            KeyLayer(
                name: "default",
                bindings: [binding("ctrl-alt-h")]
            ),
            KeyLayer(
                name: "resize",
                bindings: [
                    binding("ctrl-alt-j"),
                    binding("ctrl-alt-k"),
                ]
            ),
        ])
        #expect(over.overrideCount == 3)
    }

    /// The case that motivated the property. `diff` produces
    /// exactly this shape for an icon-only change, and the naive
    /// sum returns 0 for it.
    @Test("an icon-only layer still counts as an override")
    func iconOnlyLayerCounts() {
        let over = KeyLayerOverride(layers: [
            KeyLayer(name: "resize", icon: "arrow.up", bindings: [])
        ])
        #expect(!over.isEmpty)
        #expect(over.overrideCount == 1)
    }

    /// Read off `diff` rather than a hand-built fixture, so the
    /// shape being counted is the shape the writer produces.
    @Test("diff's icon-only output counts as an override")
    func diffIconOnly() throws {
        let base = [
            KeyLayer(
                name: "resize",
                icon: "a",
                bindings: [binding("ctrl-alt-h")]
            )
        ]
        let edited = [
            KeyLayer(
                name: "resize",
                icon: "b",
                bindings: [binding("ctrl-alt-h")]
            )
        ]
        let over = try #require(
            KeyLayerOverride.diff(base: base, edited: edited)
        )
        #expect(over.layers.allSatisfy { $0.bindings.isEmpty })
        #expect(over.overrideCount > 0)
    }

    /// The invariant, stated directly: nothing that survives
    /// `isEmpty` may count zero.
    @Test("nothing non-empty counts zero")
    func emptinessAgreesWithTheCount() {
        let cases = [
            KeyLayerOverride(),
            KeyLayerOverride(layers: [
                KeyLayer(name: "x", icon: "i", bindings: [])
            ]),
            KeyLayerOverride(layers: [
                KeyLayer(
                    name: "x",
                    bindings: [binding("ctrl-alt-h")]
                )
            ]),
        ]
        for over in cases {
            #expect(over.isEmpty == (over.overrideCount == 0))
        }
    }
}
