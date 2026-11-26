import KiwiDeskCore

/// The look picker's words (#3038, ui-designer consult 2026-11-26):
/// a card's line under its name, the key hint and what VoiceOver
/// hears.
@MainActor
enum LookPickerText {
    /// The panel's name: VoiceOver's, and the noun of the shortcut
    /// row "Show look picker".
    static var panelName: String {
        L("look_picker.panel.ax_label", "Look picker")
    }

    /// The line under a card's name.
    static func subtitle(_ entry: LookPickerEntry, worn: Bool) -> String {
        if entry.kind == .current {
            return L("look_picker.current", "Worn now · not saved")
        }
        let line =
            entry.kind == .bundled
            ? LookDescriptions.caption(for: entry.look.name) ?? ""
            : L("look_picker.saved", "Your saved look")
        guard worn else { return line }
        guard !line.isEmpty else {
            return L("look_picker.worn_alone", "Worn now")
        }
        return L("look_picker.worn", "Worn now · %1$@", line)
    }

    /// The key hint under the name.
    static func hint(
        _ entry: LookPickerEntry?,
        worn: Bool,
        naming: Bool
    ) -> String {
        if naming {
            return L("look_picker.hint.naming", "↩ Rename · Esc Keep name")
        }
        if entry?.kind == .current {
            return L(
                "look_picker.hint.current",
                "← → Browse · ⌘S Save · Esc Close"
            )
        }
        if worn {
            return L("look_picker.hint.worn", "← → Browse · Esc Close")
        }
        return L("look_picker.hint", "← → Browse · ↩ Wear · Esc Close")
    }

    /// "Name, line, 3 of 12".
    static func spoken(
        _ entry: LookPickerEntry,
        worn: Bool,
        position: Int,
        count: Int
    ) -> String {
        L(
            "look_picker.spoken",
            "%1$@, %2$@, %3$d of %4$d",
            name(entry),
            subtitle(entry, worn: worn),
            position,
            count
        )
    }

    /// The name drawn on a card: Current names itself.
    static func name(_ entry: LookPickerEntry) -> String {
        entry.kind == .current
            ? L("look_picker.current_name", "Current") : entry.look.name
    }

    /// The rename field's VoiceOver name, the Looks shelf's own
    /// rename prompt.
    static var nameField: String {
        L("looks.name_placeholder", "Look name")
    }

    static func savedAs(_ name: String) -> String {
        L("look_picker.saved_as", "Saved as %1$@", name)
    }

    static func wearing(_ name: String) -> String {
        L("look_picker.wearing", "Wearing %1$@", name)
    }

    /// The card windows' demo titles: a terminal, Settings, a note.
    static var terminalTitle: String {
        L("look_picker.demo.terminal", "zsh — ~/KiwiDesk")
    }
    /// The Settings window's own name, never a copy of it.
    static var settingsTitle: String {
        L("home.title_ax", "KiwiDesk Settings")
    }
    static var noteTitle: String {
        L("look_picker.demo.note", "Kiwi Cake")
    }
}
