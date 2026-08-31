import KiwiDeskCore

/// Catalog declarations for Whole App settings destinations
/// (`SettingsDestination.wholeApp`, `SettingsCatalog+ThisProfile.swift`).

struct ProfilesControls: Sendable {
    let savedProfiles = SettingsControl(
        "profiles.saved.title",
        "Your profiles"
    )
    /// Resolution readout card (#678 turn 13a).
    let whichProfileLoads = SettingsControl(
        "profiles.which_loads.title",
        "Which profile loads"
    )
    /// Desktop-specific profile bindings drawer (#678 turn 13a).
    let desktops = SettingsDrawer(
        "desktops.title",
        "Profiles per macOS Desktop"
    )
    let presetsCard = SettingsControl(
        "presets.title",
        "Start from a preset"
    )
    /// Hardware preset disclosures for unconnected monitor setups.
    let presetsOther = SettingsDrawer(
        "presets.other_setups",
        "For other setups"
    )
}

struct ShortcutsControls: Sendable {
    /// Layer definition and switching control card (`LayersCard`).
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
    /// Secondary size & float settings drawer.
    let sizeFloatMore = SettingsDrawer(
        "shortcuts.size_float.more",
        "Resize feedback"
    )
    let openApplications = SettingsControl(
        "shortcuts.section.open_applications",
        "Open applications"
    )
    /// General application shortcuts drawer.
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
    let appliesImmediatelyCard = SettingsControl(
        "general.applies_immediately.title",
        "Applies immediately"
    )
    let aboutCard = SettingsControl(
        "general.about.title",
        "About"
    )
    /// User guide external link declaration for search indexing
    /// (#1019, `SettingsSearchIndex`).
    let guideLink = SettingsControl(
        "general.about.guide",
        "Guide"
    )
    let generalAdvanced = SettingsDrawer(
        "general.advanced.title",
        "Advanced"
    )
}
