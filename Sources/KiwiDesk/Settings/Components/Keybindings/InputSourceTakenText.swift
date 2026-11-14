import KiwiDeskCore

/// The caption of a row that takes macOS's next-input-source
/// shortcut (#3319 ▸ Ruling amendment): what the shortcut does in
/// plain words, then where it is changed in System Settings, with
/// Apple's segment names; and, while macOS's other input-source
/// shortcut answers on a chord KiwiDesk leaves free, that this
/// chord still switches.
@MainActor
enum InputSourceTakenText {
    /// The sentence for `severity`, or nil where it is not a row
    /// taking the input-source shortcut.
    static func sentence(
        for severity: ConflictSeverity,
        config: GuiConfig,
        system: SystemShortcutState
    ) -> String? {
        let whileOpen: Bool
        switch severity {
        case .winsFromMacOS(.inputSourceNext): whileOpen = false
        case .takesFromMacOS(.inputSourceNext): whileOpen = true
        default: return nil
        }
        let chord = drawn(
            SystemShortcuts.map.first { $0.value == .inputSourceNext }?.key
        )
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
