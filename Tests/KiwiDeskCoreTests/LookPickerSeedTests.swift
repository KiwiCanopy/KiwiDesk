import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥⇧L opens the look picker (#3038 ▸ Ruling 2026-11-06), seeded on
/// "Show look picker" and reaching an existing install as
/// generation 16, only where the picker is unbound and the chord
/// free.
@Suite("Look picker seed (#3038)")
struct LookPickerSeedTests {
    private let row = DefaultKeybindings.lookPickerRow()

    @Test("the row is ⌃⌥⇧L and opens the look picker")
    func rowShape() throws {
        let combo = try #require(KeyCombo.parse(row.combo))
        #expect(combo == KeyCombo.parse("ctrl+alt+shift+l"))
        #expect(row.lua == ShelfLook.pickerLua)
        #expect(row.lua == "look.show_picker()")
        #expect(row.label == "Show look picker")
        #expect(row.kind == .navigation)
    }

    @Test("a fresh seed carries the row on each base")
    func seeded() {
        for base in ShortcutBase.allCases {
            let rows = DefaultKeybindings.bindings(
                spaces: [],
                resizeStep: 50,
                base: base
            )
            #expect(rows.filter { $0.lua == row.lua } == [base.rebased(row)])
        }
    }

    @Test("generation 16 is the row alone")
    func generation() {
        #expect(DefaultKeybindings.rows(ofGeneration: 16) == [row])
        #expect(DefaultKeybindings.newestGeneration >= 16)
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [],
                above: 15,
                base: .standard
            ).first == row
        )
    }

    @Test("a picker bound elsewhere is not offered again")
    func boundElsewhere() {
        let mine = KeyBinding(
            combo: "control+option+p",
            lua: ShelfLook.pickerLua,
            kind: .navigation
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [mine],
                above: 15,
                base: .standard
            ).isEmpty
        )
    }

    @Test("a taken ⌃⌥⇧L is not offered")
    func takenChord() {
        let mine = KeyBinding(
            combo: "control+option+shift+l",
            lua: "KiwiDesk.toggle_floating()",
            kind: .navigation
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [mine],
                above: 15,
                base: .standard
            ).isEmpty
        )
    }

    @Test("macOS reserves nothing on ⌃⌥⇧L")
    func freeOfTheSystem() throws {
        let combo = try #require(KeyCombo.parse(row.combo))
        #expect(SystemShortcuts.map[combo] == nil)
    }
}
