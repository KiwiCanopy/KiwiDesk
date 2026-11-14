import KiwiDeskCore

/// The caption of a row that takes macOS's next-input-source
/// shortcut (#3319 ▸ Ruling amendment): what the shortcut does in
/// plain words, then where it is changed in System Settings, with
/// Apple's segment names; and, while macOS's other input-source
/// shortcut answers on a chord KiwiDesk leaves free, that this
/// chord still switches. `ConflictText.sentence` asks it for the two
/// tiers that take `.inputSourceNext`.
@MainActor
enum InputSourceTakenText {
    /// The sentence for a row taking the shortcut: a step key while
    /// its sequence is open (`.takesFromMacOS`), any other row while
    /// it is bound (`.winsFromMacOS`).
    static func sentence(
        for severity: ConflictSeverity,
        config: GuiConfig,
        system: SystemShortcutState
    ) -> String {
        let whileOpen = severity == .takesFromMacOS(.inputSourceNext)
        let chord = drawn(SystemShortcuts.chord(of: .inputSourceNext))
        let place = L(
            "keybinding.conflict.input_source.place",
            "Keyboard ▸ Keyboard Shortcuts ▸ Input Sources"
        )
        guard
            let other = system.inputSourceStillSwitching(in: config)
        else {
            return whileOpen
                ? L(
                    "keybinding.conflict.tooltip.step_input_source",
                    "Takes %1$@ away from macOS's shortcut for "
                        + "switching to the next keyboard language "
                        + "(%2$@) while this sequence is open.",
                    chord,
                    place
                )
                : L(
                    "keybinding.conflict.tooltip.wins_input_source",
                    "Takes %1$@ away from macOS's shortcut for "
                        + "switching to the next keyboard language "
                        + "(%2$@) while it is bound here.",
                    chord,
                    place
                )
        }
        return whileOpen
            ? L(
                "keybinding.conflict.tooltip.step_input_source_other",
                "Takes %1$@ away from macOS's shortcut for switching "
                    + "to the next keyboard language (%2$@) while this "
                    + "sequence is open. %3$@ still switches.",
                chord,
                place,
                drawn(other)
            )
            : L(
                "keybinding.conflict.tooltip.wins_input_source_other",
                "Takes %1$@ away from macOS's shortcut for switching "
                    + "to the next keyboard language (%2$@) while it "
                    + "is bound here. %3$@ still switches.",
                chord,
                place,
                drawn(other)
            )
    }

    private static func drawn(_ combo: KeyCombo?) -> String {
        combo.map {
            ChordGlyphs.render($0, layoutChar: LayoutKeyGlyph.char)
        } ?? ""
    }
}
