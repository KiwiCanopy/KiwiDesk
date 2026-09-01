import Foundation
import Testing

@testable import KiwiDeskCore

/// `KeybindingConflicts.actionable` filters on the CALLER's
/// disabled set (#1105) — machine state is read at the GUI
/// boundary, so Core's half is only that the set it is handed
/// rules the verdict, shortcut by shortcut.
@Suite("Actionable conflict filtering")
struct KeybindingConflictFilterTests {
    private var layers: [KeyLayer] {
        var layer = KeyLayer.defaultLayer
        layer.bindings = [
            // ⌃⌥⌘8 — Invert Colors, one of the six that ship
            // disabled.
            KeyBinding(
                combo: "control+option+command+8",
                lua: "KiwiDesk.move_to_space_and_follow(\"8\")",
                kind: .navigation,
                label: "Move to Space 8 & follow"
            ),
            // ⌘Space — Spotlight, enabled everywhere sane.
            KeyBinding(
                combo: "command+space",
                lua: "KiwiDesk.focus(\"left\")",
                kind: .navigation,
                label: "Focus window to the left"
            ),
        ]
        return [layer]
    }

    @Test("only the disabled set's shortcuts are dropped")
    func disabledSetRulesTheVerdict() {
        let all = KeybindingConflicts.actionable(
            in: layers,
            disabledSystemShortcuts: []
        )
        #expect(all.count == 2)
        let filtered = KeybindingConflicts.actionable(
            in: layers,
            disabledSystemShortcuts: [.invertColors]
        )
        #expect(filtered.count == 1)
        #expect(
            filtered.first?.target
                == .systemShortcut(.spotlight)
        )
    }

    /// A duplicate-row conflict is between the user's own rows —
    /// no system state can make it unactionable.
    @Test("an other-binding conflict survives any disabled set")
    func otherBindingConflictsAlwaysCount() {
        var layer = KeyLayer.defaultLayer
        let combo = "control+option+h"
        layer.bindings = [
            KeyBinding(
                combo: combo,
                lua: "KiwiDesk.focus(\"left\")",
                kind: .navigation,
                label: "Focus window to the left"
            ),
            KeyBinding(
                combo: combo,
                lua: "KiwiDesk.focus(\"right\")",
                kind: .navigation,
                label: "Focus window to the right"
            ),
        ]
        let conflicts = KeybindingConflicts.actionable(
            in: [layer],
            disabledSystemShortcuts: Set(
                SystemShortcut.allCases
            )
        )
        #expect(conflicts.count == 2)
    }
}
