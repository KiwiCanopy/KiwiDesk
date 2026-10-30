import Testing

@testable import KiwiDeskCore

/// `KeybindingConflicts.rowConflicts(of:)` answers every row of a layer
/// from one parse of its combos, so a page of shortcut rows stops
/// parsing the layer once per row (#2783). It is only safe while it
/// answers what `conflict(for:in:)` answers row by row, so each case
/// asks both of every row, with sides told apart and not.
@Suite("A layer's conflicts answer from one parse")
struct LayerConflictsTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .custom)
    }

    /// Plain, spelled-alike, sided, Hyper, system, broken and empty
    /// rows, with a chord held three times.
    private var layer: [KeyBinding] {
        [
            row("alt+h", "a()"),
            row("option+h", "b()"),
            row("alt+h", "c()"),
            row("lcmd+j", "d()"),
            row("rcmd+j", "e()"),
            row("cmd+j", "f()"),
            row("hyper+cmd+space", "g()"),
            row("cmd+space", "h()"),
            row("nonsense+x", "i()"),
            row("", "j()"),
            row("ctrl+alt+z", "k()"),
        ]
    }

    @Test("Every row answers what the row-by-row check answers")
    func matchesRowByRow() {
        let layer = layer
        var found = 0
        for sides in [false, true] {
            let all = KeybindingConflicts.rowConflicts(
                of: layer,
                distinguishingSides: sides
            )
            for binding in layer {
                let one = KeybindingConflicts.conflict(
                    for: binding,
                    in: layer,
                    distinguishingSides: sides
                )
                #expect(all[binding.id] == one, "\(binding.combo) \(sides)")
                if one != nil { found += 1 }
            }
        }
        #expect(found > 6)
    }

    @Test("A held chord names the first other row, as the row check does")
    func firstRivalWins() {
        let layer = layer
        let all = KeybindingConflicts.rowConflicts(
            of: layer,
            distinguishingSides: true
        )
        #expect(all[layer[2].id]?.target == .otherBinding(layer[0]))
        #expect(all[layer[0].id]?.target == .otherBinding(layer[1]))
        #expect(all[layer[8].id]?.target == .unrecognized)
        #expect(all[layer[9].id] == nil)
    }
}
