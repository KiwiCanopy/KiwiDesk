import KiwiDeskCore

/// The caption of a `.firesWithMacOS` row (#3504): both fire while
/// macOS has the shortcut on, so the user turns macOS's off first.
@MainActor
enum FiresWithMacOSText {
    static func sentence(
        for shortcut: SystemShortcut,
        macOSOn: Bool
    ) -> String {
        let chord =
            SystemShortcuts.chord(of: shortcut).map {
                ChordGlyphs.render($0, layoutChar: LayoutKeyGlyph.char)
            } ?? ""
        let place = L(
            "keybinding.conflict.input_source.place",
            "Keyboard ▸ Keyboard Shortcuts ▸ Input Sources"
        )
        switch (shortcut, macOSOn) {
        case (.inputSourcePrevious, true):
            return L(
                "keybinding.conflict.tooltip.both_input_source_previous",
                "Each press of %1$@ also runs macOS's shortcut for "
                    + "switching to the previous keyboard language. To "
                    + "use %1$@ here alone, turn macOS's shortcut off "
                    + "first (%2$@).",
                chord,
                place
            )
        case (.inputSourcePrevious, false):
            return L(
                "keybinding.conflict.tooltip"
                    + ".both_input_source_previous_off",
                "macOS's shortcut for switching to the previous "
                    + "keyboard language is off (%2$@), so %1$@ only "
                    + "fires here. Turn it back on and each press "
                    + "switches the language too.",
                chord,
                place
            )
        case (_, true):
            return L(
                "keybinding.conflict.tooltip.both_macos",
                "Each press also runs %1$@ in macOS. To use this "
                    + "shortcut here alone, turn %1$@ off in System "
                    + "Settings first.",
                shortcut.localizedName
            )
        case (_, false):
            return L(
                "keybinding.conflict.tooltip.both_macos_off",
                "%1$@ is switched off in System Settings, so this "
                    + "shortcut only fires here. Turn it back on and "
                    + "each press runs it too.",
                shortcut.localizedName
            )
        }
    }
}
