import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("KeybindingConflicts")
struct KeybindingConflictsTests {
    @Test("A duplicate combo within a layer is a conflict")
    func duplicateWithinMode() {
        let bindings = [
            KeyBinding(combo: "cmd+alt+h", lua: "a"),
            KeyBinding(combo: "cmd+alt+h", lua: "b"),
        ]
        #expect(KeybindingConflicts.hasAny(bindings))
        #expect(
            KeybindingConflicts.conflict(
                for: bindings[0],
                in: bindings
            ) != nil
        )
    }

    @Test("Unique combos in one layer are not a conflict")
    func uniqueWithinMode() {
        let bindings = [
            KeyBinding(combo: "cmd+alt+h", lua: "a"),
            KeyBinding(combo: "cmd+alt+l", lua: "b"),
        ]
        #expect(!KeybindingConflicts.hasAny(bindings))
    }

    @Test(
        "The same combo in different layers is not a conflict"
    )
    func sameComboAcrossModes() {
        let layers = [
            KeyLayer(
                name: "default",
                bindings: [KeyBinding(combo: "h", lua: "a")]
            ),
            KeyLayer(
                name: "resize",
                bindings: [KeyBinding(combo: "h", lua: "b")]
            ),
        ]
        #expect(
            !KeybindingConflicts.hasAnyAcrossLayers(layers)
        )
    }

    @Test("A conflict inside any single layer is reported")
    func conflictWithinOneOfSeveralModes() {
        let layers = [
            KeyLayer(
                name: "default",
                bindings: [KeyBinding(combo: "h", lua: "a")]
            ),
            KeyLayer(
                name: "resize",
                bindings: [
                    KeyBinding(combo: "j", lua: "b"),
                    KeyBinding(combo: "j", lua: "c"),
                ]
            ),
        ]
        #expect(KeybindingConflicts.hasAnyAcrossLayers(layers))
    }

    @Test("conflicts(in:) names a system-shortcut clash")
    func conflictsReportsSystemShortcut() {
        let layers = [
            KeyLayer(
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
        let list = KeybindingConflicts.conflicts(in: layers)
        #expect(list.count == 1)
        #expect(list[0].binding.label == "Close")
        // The case, never its English name (#96): Core cannot
        // reach `L()`, so the GUI resolves the display string.
        #expect(list[0].target == .systemShortcut(.closeWindow))
    }

    @Test("conflicts(in:) names an intra-layer duplicate")
    func conflictsReportsOtherBinding() {
        let layers = [
            KeyLayer(
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
        let list = KeybindingConflicts.conflicts(in: layers)
        #expect(list.count == 2)
        // Each side carries the BINDING; the GUI names it (#2116).
        #expect(list[0].binding == layers[0].bindings[0])
        #expect(list[0].target == .otherBinding(layers[0].bindings[1]))
        #expect(list[1].binding == layers[0].bindings[1])
        #expect(list[1].target == .otherBinding(layers[0].bindings[0]))
    }

    /// Core picks no name for a label-less row: it hands the GUI
    /// the binding, which names it by its catalog name or its Lua
    /// (#2116), never by its combo.
    @Test("conflicts(in:) carries an unnamed row whole")
    func conflictsCarriesTheUnnamedRow() {
        let layers = [
            KeyLayer(
                name: "default",
                bindings: [
                    KeyBinding(combo: "cmd+w", lua: "a")
                ]
            )
        ]
        let list = KeybindingConflicts.conflicts(in: layers)
        #expect(list.count == 1)
        #expect(list[0].binding == layers[0].bindings[0])
    }

    @Test("conflicts(in:) flags an unparseable combo")
    func conflictsReportsUnrecognized() {
        let layers = [
            KeyLayer(
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
        let list = KeybindingConflicts.conflicts(in: layers)
        #expect(list.count == 1)
        #expect(list[0].binding.label == "Bad")
        #expect(list[0].target == .unrecognized)
    }
}
