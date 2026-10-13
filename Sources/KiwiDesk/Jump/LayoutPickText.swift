import KiwiDeskCore

/// The Layouts scope's words (#2229): Core hands the facts in
/// `LayoutPickerState`, the GUI narrates them (#96).
@MainActor
enum LayoutPickText {
    /// The line under the field: the Space, its layout, and
    /// whether that layout is a temporary one.
    static func caption(_ state: LayoutPickerState) -> String {
        let space = state.space.raw
        let mode = state.live.displayName
        guard state.drifted else {
            return L(
                "layout_picker.caption",
                "Space %1$@ · %2$@",
                space,
                mode
            )
        }
        return L(
            "layout_picker.caption_unsaved",
            "Space %1$@ · %2$@ — not saved to profile",
            space,
            mode
        )
    }

    static func noMatch(_ query: String) -> String {
        L("layout_picker.no_match", "No layout matches “%1$@”", query)
    }

    /// A tile as VoiceOver hears it.
    static func spoken(_ mode: LayoutMode, current: Bool) -> String {
        guard current else { return mode.displayName }
        return L(
            "layout_picker.ax.current",
            "%1$@, current layout",
            mode.displayName
        )
    }

    static func keep(_ profile: String) -> String {
        L("layout_picker.keep", "Keep in Profile “%1$@”", profile)
    }

    /// Why Keep is greyed, for VoiceOver.
    static var keepSaved: String {
        L(
            "layout_picker.keep_saved",
            "Every layout on screen is saved in the profile"
        )
    }

    static var layoutDefaults: String {
        L(
            "layout_picker.layout_defaults",
            "%1$@…",
            L("destination.layout", "Layout Defaults")
        )
    }

    /// A button's chord, spoken as a hint rather than its name.
    static func chordHint(_ chord: String) -> String {
        L("layout_picker.ax.chord", "Shortcut: %1$@", chord)
    }
}
