import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The row's reading of a conflict (#1126): the same Core
/// `Conflict` reads DEAD or DORMANT by the machine's live
/// enabled state (#1105), and only a live macOS chord is dead.
/// Pure — no model, no locale, no scan. Conflicts come through
/// the one public door, `KeybindingConflicts.conflict`, which is
/// also the door `ConflictText.severity` takes.
struct ConflictSeverityTests {
    private func row(
        _ combo: String,
        _ label: String,
        lua: String = "KiwiDesk.focus(\"left\")"
    ) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: lua,
            kind: .navigation,
            label: label
        )
    }

    /// ⌘Space is Spotlight, a symbolic hotkey that ships ON; ⌘W
    /// is Close Window, a register chord with no symbolic id;
    /// ⌃⌥⌘8 is Invert Colors, one of the chords that ships OFF.
    private func conflict(
        _ combo: String,
        in others: [KeyBinding] = []
    ) -> Conflict? {
        let binding = row(combo, "Focus window left")
        return KeybindingConflicts.conflict(
            for: binding,
            in: [binding] + others
        )
    }

    /// Measured 2026-09-03 (#1126): macOS answers an enabled
    /// symbolic hotkey before the binding hears the press.
    @Test("a live symbolic hotkey reads dead")
    func liveSymbolicHotkeyIsDead() throws {
        let spotlight = try #require(conflict("command+space"))
        let severity = ConflictSeverity.of(spotlight, disabled: [])
        #expect(severity == .dead(.spotlight))
        #expect(severity.isDead)
    }

    /// A register chord with no symbolic id (⌘W) has no measured
    /// press precedence, so it is a collision, never a death.
    @Test("a register chord outside the symbolic table is reserved")
    func hardWiredChordIsReserved() throws {
        let closeWindow = try #require(conflict("command+w"))
        let severity = ConflictSeverity.of(closeWindow, disabled: [])
        #expect(severity == .reserved(.closeWindow))
        #expect(!severity.isDead)
    }

    /// The population the static set was wrong for, both ways
    /// (#1105): the SAME conflict is dormant on a machine that
    /// has Invert Colors off and dead on one that has it on.
    @Test("a switched-off macOS chord reads dormant, not dead")
    func disabledSystemChordIsDormant() throws {
        let invert = try #require(
            conflict("control+option+command+8")
        )
        let off = ConflictSeverity.of(
            invert,
            disabled: [.invertColors]
        )
        #expect(off == .dormant(.invertColors))
        #expect(!off.isDead)
        let on = ConflictSeverity.of(invert, disabled: [])
        #expect(on == .dead(.invertColors))
    }

    /// The disabled set is read per SHORTCUT: another family
    /// being off says nothing about this chord.
    @Test("another chord's disablement does not soften this one")
    func disablementIsPerShortcut() throws {
        let spotlight = try #require(conflict("command+space"))
        let severity = ConflictSeverity.of(
            spotlight,
            disabled: [.invertColors, .zoomToggle]
        )
        #expect(severity == .dead(.spotlight))
    }

    /// One of two duplicate rows fires (the layer is one
    /// `[KeyCombo: ref]` table), so a duplicate is never DEAD
    /// — the loud treatment is reserved for a row that cannot
    /// fire at all.
    @Test("a duplicate and an unrecognized chord are not dead")
    func duplicateAndUnrecognizedAreNotDead() throws {
        let twin = row(
            "alt+h",
            "Focus window right",
            lua: "KiwiDesk.focus(\"right\")"
        )
        let duplicate = ConflictSeverity.of(
            try #require(conflict("alt+h", in: [twin])),
            disabled: []
        )
        #expect(duplicate == .duplicate("Focus window right"))
        #expect(!duplicate.isDead)
        let unrecognized = ConflictSeverity.of(
            try #require(conflict("not+a+key")),
            disabled: []
        )
        #expect(unrecognized == .unrecognized)
        #expect(!unrecognized.isDead)
    }

    /// The tooltip's reading is the severity's, through the one
    /// `ConflictText.severity` door: a row with no conflict has
    /// no severity, and a duplicate within the layer is found
    /// against the rows it is handed.
    @Test("ConflictText derives the severity from the row's list")
    func textDerivesFromTheRow() {
        let left = row("alt+h", "Focus window left")
        let right = row(
            "alt+h",
            "Focus window right",
            lua: "KiwiDesk.focus(\"right\")"
        )
        let clean = row(
            "alt+j",
            "Focus window down",
            lua: "KiwiDesk.focus(\"down\")"
        )
        #expect(
            ConflictText.severity(
                for: left,
                in: [left, right],
                disabled: []
            ) == .duplicate("Focus window right")
        )
        #expect(
            ConflictText.severity(
                for: clean,
                in: [left, right, clean],
                disabled: []
            ) == nil
        )
        let commandSpace = row("command+space", "Focus window left")
        #expect(
            ConflictText.severity(
                for: commandSpace,
                in: [commandSpace],
                disabled: []
            ) == .dead(.spotlight)
        )
    }
}
