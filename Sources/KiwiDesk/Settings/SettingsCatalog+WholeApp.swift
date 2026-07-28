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
    let switchModes = SettingsControl(
        "shortcuts.section.switch_modes",
        "Switch modes"
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
    let openApplications = SettingsControl(
        "shortcuts.section.open_applications",
        "Open applications"
    )
    let generalKeys = SettingsControl(
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
    let languageCard = SettingsControl(
        "general.language.title",
        "Language"
    )
    // Terse topic-noun heading; the dropdown inside carries the
    // verb "Start KiwiDesk" (#576), as every card pairs a noun
    // with an action.
    let loginItemCard = SettingsControl(
        "general.login_item.title",
        "Login"
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
