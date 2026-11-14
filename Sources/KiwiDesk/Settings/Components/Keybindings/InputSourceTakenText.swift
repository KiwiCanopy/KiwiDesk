import KiwiDeskCore

/// The caption of a row that takes one of macOS's two input-source
/// shortcuts (#3319 ▸ Ruling amendment, #3331): what the shortcut
/// does in plain words, then where it is changed in System Settings,
/// with Apple's segment names; and, while the other input-source
/// shortcut answers on a chord KiwiDesk leaves free, that this chord
/// still switches. `ConflictText.sentence` asks it for the tiers
/// that take `.inputSourceNext` or `.inputSourcePrevious`.
@MainActor
enum InputSourceTakenText {
    /// The sentence for a row taking `shortcut`: a step key while
    /// its sequence is open (`.takesFromMacOS`), any other row while
    /// it is bound (`.winsFromMacOS`).
    static func sentence(
        for severity: ConflictSeverity,
        taking shortcut: SystemShortcut,
        config: GuiConfig,
        system: SystemShortcutState
    ) -> String {
        let whileOpen = severity == .takesFromMacOS(shortcut)
        let chord = drawn(SystemShortcuts.chord(of: shortcut))
        let place = L(
            "keybinding.conflict.input_source.place",
            "Keyboard ▸ Keyboard Shortcuts ▸ Input Sources"
        )
        let other = system.inputSourceStillSwitching(
            besides: shortcut,
            in: config
        )
        let previous = shortcut == .inputSourcePrevious
        switch (previous, whileOpen, other) {
        case (false, _, _):
            return next(
                whileOpen: whileOpen,
                chord: chord,
                place: place,
                other: other.map(drawn)
            )
        case (true, true, nil):
            return L(
                "keybinding.conflict.tooltip.step_input_source_previous",
                "Takes %1$@ away from macOS's shortcut for "
                    + "switching to the previous keyboard language "
                    + "(%2$@) while this sequence is open.",
                chord,
                place
            )
        case (true, false, nil):
            return L(
                "keybinding.conflict.tooltip.wins_input_source_previous",
                "Takes %1$@ away from macOS's shortcut for "
                    + "switching to the previous keyboard language "
                    + "(%2$@) while it is bound here.",
                chord,
                place
            )
        case (true, true, let other?):
            return L(
                "keybinding.conflict.tooltip"
                    + ".step_input_source_previous_other",
                "Takes %1$@ away from macOS's shortcut for switching "
                    + "to the previous keyboard language (%2$@) while "
                    + "this sequence is open. %3$@ still switches.",
                chord,
                place,
                drawn(other)
            )
        case (true, false, let other?):
            return L(
                "keybinding.conflict.tooltip"
                    + ".wins_input_source_previous_other",
                "Takes %1$@ away from macOS's shortcut for switching "
                    + "to the previous keyboard language (%2$@) while "
                    + "it is bound here. %3$@ still switches.",
                chord,
                place,
                drawn(other)
            )
        }
    }

    /// The four sentences for "Select next source in Input menu"
    /// (#3319).
    private static func next(
        whileOpen: Bool,
        chord: String,
        place: String,
        other: String?
    ) -> String {
        guard let other else {
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
                other
            )
            : L(
                "keybinding.conflict.tooltip.wins_input_source_other",
                "Takes %1$@ away from macOS's shortcut for switching "
                    + "to the next keyboard language (%2$@) while it "
                    + "is bound here. %3$@ still switches.",
                chord,
                place,
                other
            )
    }

    private static func drawn(_ combo: KeyCombo?) -> String {
        combo.map {
            ChordGlyphs.render($0, layoutChar: LayoutKeyGlyph.char)
        } ?? ""
    }
}
