import KiwiDeskCore

// The declaration structs behind the sidebar's **Whole App**
// group (`SettingsDestination.wholeApp`): Profiles, Shortcuts,
// App Rules, General. Split from `SettingsCatalog.swift` on the
// seam the sidebar already draws — see the note atop
// `SettingsCatalog+ThisProfile.swift`.

struct ProfilesControls: Sendable {
    let savedProfiles = SettingsControl(
        "profiles.saved.title",
        "Your profiles"
    )
    /// The resolution sentence (#678 turn 13a) — "the sentence
    /// most people never find in the current UI". A card of its
    /// own so search can land it: "which profile loads" is the
    /// question the area exists to answer, and until turn 13a it
    /// was answerable only by reading the list and inferring the
    /// rule.
    let whichProfileLoads = SettingsControl(
        "profiles.which_loads.title",
        "Which profile loads"
    )
    /// A drawer since #678 turn 13a: the census tiers
    /// `profileBindings` `.showMore`, and a Show-more row lives
    /// behind its container's disclosure.
    let nativeSpaces = SettingsDrawer(
        "native_spaces.title",
        "Profiles per macOS Space"
    )
    let presetsCard = SettingsControl(
        "presets.title",
        "Start from a preset"
    )
    /// Presets for screen counts that are NOT connected. A
    /// disclosure named for what it holds, never a bare "Show
    /// more" — and its own declaration, so search can land a
    /// preset the live hardware cannot apply.
    let presetsOther = SettingsDrawer(
        "presets.other_setups",
        "For other setups"
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
    /// A `SettingsControl`, not a `SettingsDrawer`: since the
    /// owner ruling of 2026-08-04 the card is always open when it
    /// is shown at all, and withholds itself entirely when it is
    /// not (`LayersCard`). A drawer declaration would promise a
    /// disclosure that no longer exists, and its `childIDs` exist
    /// to auto-expand one.
    let layersCard = SettingsControl(
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
