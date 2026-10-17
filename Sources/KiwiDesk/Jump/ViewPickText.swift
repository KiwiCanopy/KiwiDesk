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

    /// KiwiVision's base settings, which a lens overrides (#2103
    /// ruling 55).
    static var visionDefault: String {
        L("view_picker.vision.default", "Default")
    }

    /// What ↩ or a click does on the current KiwiVision chip,
    /// spoken ahead of its ⌘ hint (#2103 ruling 56).
    static var turnsOffHint: String {
        L("view_picker.vision.turns_off", "Turns KiwiVision off")
    }

    /// A chip's VoiceOver hint: the KiwiVision item already on says
    /// it turns KiwiVision off, ahead of its ⌘ hint (#2103 ruling
    /// 56), the two joined in one localized frame.
    static func hint(for item: ViewPickList.Item, number: Int?) -> String {
        let chord = number.map { LayoutPickText.chordHint("⌘\($0)") }
        guard ViewPickList.action(of: item) == .visionOff else {
            return chord ?? ""
        }
        guard let chord else { return turnsOffHint }
        return L("view_picker.ax.hint_pair", "%1$@, %2$@", turnsOffHint, chord)
    }

    /// The footer's lit hint while ↩ turns KiwiVision off.
    static var turnOffFooter: String {
        L("view_picker.footer.turn_off", "%1$@ Turn Off", "↩")
    }

    /// The KiwiVision line's last chip (#2103 ruling 57).
    static var newLens: String {
        L("kiwivision.lens.new", "New Lens…")
    }

    /// Why New Lens… greys where `init.lua` owns the setup and
    /// defines its lenses (gui.md: grey, don't hide).
    static var newLensLuaOwned: String {
        L("view_picker.vision.new_lens_lua", "Lenses come from init.lua")
    }

    /// Why a lens chip cannot turn its lens on (#2103).
    static func lensRefusal(_ refusal: LensRefusal) -> String {
        switch refusal {
        case .noApps:
            return L("view_picker.vision.lens_empty", "No apps yet")
        case .outOfReach(let profile):
            return L(
                "view_picker.vision.lens_out_of_reach",
                "Not in %1$@",
                profile
            )
        }
    }

    /// The Profile line's last chip (#2359 ruling 2), Settings'
    /// own words for the same save.
    static var newProfile: String {
        L("footer.save_as_new_profile", "Save as New Profile…")
    }

    /// The name the field starts from, made free by Core.
    static var newProfileBase: String {
        L("view_picker.profile.new_name", "New Profile")
    }

    /// The field's prompt and VoiceOver name while it names a
    /// profile.
    static var namingPrompt: String {
        L("view_picker.profile.name_prompt", "Profile name")
    }

    /// The one line under the field: what ↩ writes, and that the
    /// new profile then holds these screens — a save claims the
    /// connected screen setup (#2359 ruling 3, profiles.md).
    static func savesAs(_ name: String) -> String {
        L(
            "view_picker.profile.saves_holding",
            "↩ saves your Spaces and layouts as “%1$@”, which then "
                + "holds these screens",
            name
        )
    }

    /// What VoiceOver hears as naming starts: the field and what
    /// ↩ will write.
    static func namingSpoken(_ name: String) -> String {
        L("view_picker.ax.naming", "%1$@, %2$@", namingPrompt, savesAs(name))
    }

    /// The line under the field when a save did not land.
    static var saveFailed: String {
        L("view_picker.profile.save_failed", "Couldn't save the profile")
    }

    /// The line under the field where the typing cannot name a
    /// profile.
    static var invalidName: String {
        L(
            "view_picker.profile.invalid_name",
            "A profile name can't be empty, start with a dot or "
                + "contain “/”"
        )
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

    /// Every line's caption while window management is held
    /// (#2050), nil once it runs.
    static func held(_ hold: CoreHold) -> String? {
        switch hold {
        case .running: return nil
        case .notStarted:
            return L("view_picker.not_tiling", "Tiling hasn't started")
        case .permissionMissing:
            return L(
                "view_picker.no_permission",
                "Needs Accessibility permission"
            )
        }
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
        on line: ViewPickList.Line,
        visionOff: Bool = false
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
        // With nothing on, no chip says "current": the line says
        // KiwiVision is off (#2103 ruling 56).
        let heading =
            line == .vision && visionOff
            ? L("view_picker.ax.vision_off", "%1$@, off", title(line))
            : title(line)
        return L("view_picker.ax.item", "%1$@: %2$@", heading, name)
    }

    /// The Settings page a line's ⌘, opens; the line's heading and
    /// that button wear its symbol.
    static func destination(
        _ line: ViewPickList.Line
    ) -> SettingsDestination {
        switch line {
        case .layout: return .layoutDefaults
        case .profile: return .profiles
        case .vision: return .kiwiVision
        }
    }

    /// Every label the View side's Settings button can wear, which
    /// it reserves the width of.
    static var settingsLabels: [KeyPanelChordButton.Label] {
        ViewPickList.Line.allCases.map {
            KeyPanelChordButton.Label(
                title: settings($0),
                symbol: destination($0).symbol
            )
        }
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
