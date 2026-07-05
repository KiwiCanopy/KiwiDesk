import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("KeybindingConflicts")
struct KeybindingConflictsTests {
    @Test("A duplicate combo within a mode is a conflict")
    func duplicateWithinMode() {
        let bindings = [
            KeyBinding(combo: "cmd+alt+h", lua: "a"),
            KeyBinding(combo: "cmd+alt+h", lua: "b"),
        ]
        #expect(KeybindingConflicts.hasAny(bindings))
        #expect(
            KeybindingConflicts.text(
                for: bindings[0],
                in: bindings
            ) != nil
        )
    }

    @Test("Unique combos in one mode are not a conflict")
    func uniqueWithinMode() {
        let bindings = [
            KeyBinding(combo: "cmd+alt+h", lua: "a"),
            KeyBinding(combo: "cmd+alt+l", lua: "b"),
        ]
        #expect(!KeybindingConflicts.hasAny(bindings))
    }

    @Test(
        "The same combo in different modes is not a conflict"
    )
    func sameComboAcrossModes() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [KeyBinding(combo: "h", lua: "a")]
            ),
            KeyMode(
                name: "resize",
                bindings: [KeyBinding(combo: "h", lua: "b")]
            ),
        ]
        #expect(
            !KeybindingConflicts.hasAnyAcrossModes(modes)
        )
    }

    @Test("A conflict inside any single mode is reported")
    func conflictWithinOneOfSeveralModes() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [KeyBinding(combo: "h", lua: "a")]
            ),
            KeyMode(
                name: "resize",
                bindings: [
                    KeyBinding(combo: "j", lua: "b"),
                    KeyBinding(combo: "j", lua: "c"),
                ]
            ),
        ]
        #expect(KeybindingConflicts.hasAnyAcrossModes(modes))
    }

    @Test("conflicts(in:) names a system-shortcut clash")
    func conflictsReportsSystemShortcut() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "command+w",
                        lua: "a",
                        label: "Close"
                    )
                ]
            )
        ]
        let list = KeybindingConflicts.conflicts(in: modes)
        #expect(list.count == 1)
        #expect(list[0].name == "Close")
        #expect(
            list[0].target
                == .systemShortcut("Close Window")
        )
    }

    @Test("conflicts(in:) names an intra-mode duplicate")
    func conflictsReportsOtherBinding() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "cmd+alt+h",
                        lua: "a",
                        label: "First"
                    ),
                    KeyBinding(
                        combo: "cmd+alt+h",
                        lua: "b",
                        label: "Second"
                    ),
                ]
            )
        ]
        let list = KeybindingConflicts.conflicts(in: modes)
        #expect(list.count == 2)
        #expect(list[0].name == "First")
        #expect(list[0].target == .otherBinding("Second"))
        #expect(list[1].name == "Second")
        #expect(list[1].target == .otherBinding("First"))
    }

    @Test("conflicts(in:) falls back to the combo for an unnamed row")
    func conflictsFallsBackToCombo() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(combo: "cmd+w", lua: "a")
                ]
            )
        ]
        let list = KeybindingConflicts.conflicts(in: modes)
        #expect(list.count == 1)
        #expect(list[0].name == "cmd+w")
    }

    @Test("conflicts(in:) flags an unparseable combo")
    func conflictsReportsUnrecognized() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "hyper+z",
                        lua: "a",
                        label: "Bad"
                    )
                ]
            )
        ]
        let list = KeybindingConflicts.conflicts(in: modes)
        #expect(list.count == 1)
        #expect(list[0].name == "Bad")
        #expect(list[0].target == .unrecognized)
    }
}
