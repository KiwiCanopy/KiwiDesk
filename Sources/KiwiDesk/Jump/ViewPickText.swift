import KiwiDeskCore

/// The View side's words (#2309); the Layout line's own words stay
/// `LayoutPickText`'s.
@MainActor
enum ViewPickText {
    static func title(_ line: ViewPickList.Line) -> String {
        switch line {
        case .layout: return L("view_picker.line.layout", "Layout")
        case .profile: return L("view_picker.line.profile", "Profile")
        case .vision: return L("destination.kiwivision", "KiwiVision")
        }
    }

    static var visionOff: String { L("view_picker.vision.off", "Off") }

    static var visionFocused: String {
        L("view_picker.vision.focused", "Focused window")
    }

    /// A profile the menu greys for the same reason (#246).
    static var profileBroken: String {
        L("view_picker.profile.broken", "Can't load")
    }

    /// The Layout line's caption where no Space is under the
    /// pointer.
    static var noSpace: String {
        L("view_picker.layout.no_space", "No Space under the pointer")
    }

    /// Every line's caption while KiwiDesk boots.
    static var starting: String {
        L("view_picker.starting", "KiwiDesk is starting")
    }

    static func noMatch(_ query: String) -> String {
        L("view_picker.no_match", "Nothing matches “%1$@”", query)
    }

    /// An item as VoiceOver hears it: its line, its name, whether
    /// it is current, and why it cannot be applied.
    static func spoken(
        _ item: ViewPickList.Item,
        on line: ViewPickList.Line
    ) -> String {
        var name = item.name
        if item.isCurrent {
            name = L("view_picker.ax.current", "%1$@, current", name)
        }
        if let refusal = item.refusal ?? item.inertReason {
            name = L(
                "view_picker.ax.refused",
                "%1$@, %2$@",
                name,
                refusal
            )
        }
        return L("view_picker.ax.item", "%1$@: %2$@", title(line), name)
    }

    /// The Settings button: the page of the line the selection is
    /// on.
    static func settings(_ line: ViewPickList.Line) -> String {
        switch line {
        case .layout:
            return L(
                "layout_picker.layout_defaults",
                "%1$@…",
                L("destination.layout", "Layout Defaults")
            )
        case .profile:
            return L(
                "layout_picker.layout_defaults",
                "%1$@…",
                L("destination.profiles", "Profiles")
            )
        case .vision:
            return L(
                "layout_picker.layout_defaults",
                "%1$@…",
                L("destination.kiwivision", "KiwiVision")
            )
        }
    }

    static func lineHint(_ arrows: String) -> String {
        L("view_picker.footer.line", "%1$@ Line", arrows)
    }
}
