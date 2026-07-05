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
}
