import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The red ring's own fold: two bindings in ONE layer claiming
/// the same combo. It replaced a join through display NAMES —
/// `Conflict.name` matched against `KeyBinding.label` — which
/// never ringed an unlabelled binding and matched across layers,
/// though conflicts are per layer.
@Suite("Keyboard preview collisions")
struct KeyboardCollisionTests {
    private func layer(
        _ combos: [String],
        name: String = KeyLayer.defaultName,
        labels: [String]? = nil
    ) -> KeyLayer {
        KeyLayer(
            name: name,
            bindings: combos.enumerated().map { index, combo in
                KeyBinding(
                    combo: combo,
                    lua: "focus_dir('left')",
                    label: labels?[index] ?? "row \(index)"
                )
            }
        )
    }

    @Test("Two bindings on one combo in one layer collide")
    func sameLayerDuplicateCollides() {
        let codes = KeyboardCensus.collisions(
            in: [layer(["ctrl+alt+j", "ctrl+alt+j"])],
            scope: .all
        )
        #expect(codes == [38])
    }

    /// The defect the name-join shipped: a binding with no label
    /// took `Conflict.name`'s combo fallback, so the filter could
    /// never match it and the key went unringed.
    @Test("An unlabelled binding still collides")
    func unlabelledBindingStillCollides() {
        let codes = KeyboardCensus.collisions(
            in: [
                layer(
                    ["ctrl+alt+j", "ctrl+alt+j"],
                    labels: ["", ""]
                )
            ],
            scope: .all
        )
        #expect(codes == [38])
    }

    /// Conflicts are per layer — `KeybindingConflicts` never
    /// compares across them, so neither may this.
    @Test("The same combo in two layers is not a collision")
    func acrossLayersIsNotACollision() {
        let codes = KeyboardCensus.collisions(
            in: [
                layer(["ctrl+alt+j"]),
                layer(["ctrl+alt+j"], name: "media"),
            ],
            scope: .all
        )
        #expect(codes.isEmpty)
    }

    /// Scope-blind was the other half of the defect: a ring drawn
    /// on a key the current scope shows as FREE puts `danger` on
    /// `keyFree`, a pair the ring's colour was never measured
    /// against.
    @Test("A collision outside the shown scope is not ringed")
    func collisionsFollowTheScope() {
        let layers = [layer(["cmd+j", "cmd+j"])]
        let ctrlOpt = KeyboardCensus.ModifierLayer(
            modifiers: [.control, .option]
        )
        #expect(
            KeyboardCensus.collisions(
                in: layers,
                scope: .one(ctrlOpt)
            ).isEmpty
        )
        #expect(
            !KeyboardCensus.collisions(
                in: layers,
                scope: .one(
                    KeyboardCensus.ModifierLayer(
                        modifiers: .command
                    )
                )
            ).isEmpty
        )
    }
}
