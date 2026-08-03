import KiwiDeskCore

// The declaration structs behind the sidebar's **Whole App**
// group (`SettingsDestination.wholeApp`): Profiles, Shortcuts,
// App Rules, General. Split from `SettingsCatalog.swift` on the
// seam the sidebar already draws — see the note atop
// `SettingsCatalog+ThisProfile.swift`.

struct ProfilesControls: Sendable {
    let savedProfiles = SettingsControl(
        "profiles.saved.title",
        "Saved profiles"
    )
    let presetsCard = SettingsControl("presets.title", "Presets")
    let nativeSpaces = SettingsControl(
        "native_spaces.title",
        "Profiles per macOS Space"
    )
}

struct ShortcutsControls: Sendable {
    /// The Layers card. A drawer, not a plain section: the
    /// census tiers every family in this container `.showMore`,
    /// so alternate key sets are one interaction away rather
    /// than in a first-week user's path.
    ///
    /// Titled for the container, not for one of its parts — it
    /// holds the strip that DEFINES the layers as well as the
    /// rows that switch between them. The ⌃⌥K panel keeps
    /// `shortcuts.section.switch_layers` for its band, which
    /// really is only the switch rows.
    let layersCard = SettingsDrawer(
        "shortcuts.section.layers",
        "Layers"
    )
    let focusKeys = SettingsControl(
        "shortcuts.section.focus",
        "Focus"
    )
    let moveWindows = SettingsControl(
        "shortcuts.section.move_windows",
        "Move windows"
    )
    let sizeFloat = SettingsControl(
        "shortcuts.section.size_float",
        "Size & float"
    )
    /// Size & float's disclosure. Named for what it hides
    /// rather than "Show more" — a disclosure row names its
    /// contents (the redesign's GUI rules).
    let sizeFloatMore = SettingsDrawer(
        "shortcuts.size_float.more",
        "Resize feedback"
    )
    let openApplications = SettingsControl(
        "shortcuts.section.open_applications",
        "Open applications"
    )
    /// Also a drawer: its one row (`showShortcuts`) is census
    /// `.showMore`, being app chrome rather than a workspace
    /// action.
    let generalKeys = SettingsDrawer(
        "shortcuts.section.general",
        "General"
    )
    let inactiveShortcuts = SettingsControl(
        "shortcuts.section.inactive",
        "Inactive shortcuts"
    )
    let profileShortcuts = SettingsControl(
        "shortcuts.override.title",
        "Profile shortcuts"
    )
    let luaBindings = SettingsDrawer(
        "shortcuts.advanced.title",
        "Lua bindings"
    )
}

struct AppRulesControls: Sendable {
    let rulesPerApp = SettingsControl(
        "app_rules.section.title",
        "Rules per app"
    )
}

struct GeneralControls: Sendable {
    // Turn 14b's first group. These rows are grouped by the RULE
    // they share, not by topic: none is part of a profile and
    // none is touched by the footer's Save. The heading says so,
    // because otherwise Revert appears to undo them and does not
    // — the 6b audit's fourth finding.
    let appliesImmediatelyCard = SettingsControl(
        "general.applies_immediately.title",
        "Applies immediately"
    )
    let aboutCard = SettingsControl(
        "general.about.title",
        "About"
    )
    let generalAdvanced = SettingsDrawer(
        "general.advanced.title",
        "Advanced"
    )
}
