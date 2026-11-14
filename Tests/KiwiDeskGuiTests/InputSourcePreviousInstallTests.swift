import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// What reserving ⌃Space for macOS's previous-input-source shortcut
/// does to an existing install (#3331): no seed binds the chord, so
/// Home's count is unchanged; a user's own row on it counts while
/// hotkey 60 is on; and the keyboard board marks Space as macOS's
/// under a ⌃ layer.
@Suite("Reserving ⌃Space on an existing install (#3331)")
struct InputSourcePreviousInstallTests {
    private let ctrlSpace = KeyCombo.parse("control+space")!

    private func seeded(_ base: ShortcutBase) -> [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
            resizeStep: 50,
            base: base
        )
            + (1...10).compactMap {
                DefaultKeybindings.desktopRow($0, base: base)
            }
    }

    private func count(
        _ rows: [KeyBinding],
        disabled: Set<SystemShortcut> = []
    ) -> Int {
        KeybindingConflicts.actionable(
            in: [KeyLayer(name: KeyLayer.defaultName, bindings: rows)],
            disabledSystemShortcuts: disabled,
            distinguishingSides: false
        ).filter {
            if case .systemShortcut(.inputSourcePrevious, _) = $0.target {
                return true
            }
            return false
        }.count
    }

    @Test("no seed on either base binds ⌃Space")
    func seedsLeaveTheChordFree() {
        for base in ShortcutBase.allCases {
            let rows = seeded(base)
            #expect(rows.count > 20)
            #expect(!rows.contains { KeyCombo.parse($0.combo) == ctrlSpace })
            #expect(count(rows) == 0)
        }
    }

    @Test("a user's row on ⌃Space counts while hotkey 60 is on")
    func userRowCounts() {
        let row = KeyBinding(combo: "control+space", lua: "a")
        #expect(count([row]) == 1)
        #expect(count([row], disabled: [.inputSourcePrevious]) == 0)
    }

    @Test("the board marks Space as macOS's under ⌃ alone")
    func boardMarksSpace() {
        let control = KeyboardCensus.Scope.one(
            KeyboardCensus.ModifierLayer(modifiers: .control)
        )
        #expect(KeyboardCensus.reservedKeys(scope: control).contains(49))
        #expect(
            KeyboardCensus.reservedOwner(of: 49, scope: control)
                == .inputSourcePrevious
        )
        let both = KeyboardCensus.Scope.one(
            KeyboardCensus.ModifierLayer(modifiers: [.control, .option])
        )
        #expect(
            KeyboardCensus.reservedOwner(of: 49, scope: both)
                == .inputSourceNext
        )
    }
}
