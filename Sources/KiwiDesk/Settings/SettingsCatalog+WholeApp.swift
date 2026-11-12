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

struct AppRulesControls: Sendable {
    let spaceList = SettingsControl(
        "app_rules.space_list.title",
        "Open in a Space"
    )
    let floatList = SettingsControl(
        "app_rules.float_list.title",
        "Float"
    )
    let automaticList = SettingsControl(
        "app_rules.auto_list.title",
        "Automatic floating"
    )
}

struct GeneralControls: Sendable {
    // Grouped by the RULE they share, not by topic: none is
    // part of a profile and none is touched by Save — the heading
    // says so, or Revert appears to undo them and does not (6b
    // audit, fourth finding).
    let appliesImmediatelyCard = SettingsControl(
        "general.applies_immediately.title",
        "Changes apply at once, in every profile"
    )
    /// The Sync across Macs group, where the quick menu's Sync
    /// Paused… row lands (#3088); keyed on its census label.
    let syncAcrossMacs = SettingsControl(
        "general.sync",
        "Sync across Macs"
    )
    /// Declared with its children so a search hit on any of
    /// them opens the drawer it lands in (#1250).
    let generalAdvanced = SettingsDrawer(
        "general.advanced.title",
        "Files & Reset",
        children: GeneralAdvancedControls()
    )
}

/// General ▸ Files & Reset rows, keyed on their census label keys so
/// the census hit resolves to the row (#1250).
struct GeneralAdvancedControls: Sendable {
    let configFile = SettingsControl(
        "general.advanced.config_file",
        "Configuration file"
    )
    let editLua = SettingsControl(
        "general.advanced.edit_lua",
        "Edit init.lua directly"
    )
    let exportBackup = SettingsControl(
        "general.advanced.backup.export",
        "Export KiwiDesk Backup…"
    )
    let exportLog = SettingsControl(
        "general.advanced.log.export",
        "Export Log…"
    )
    let logRange = SettingsControl(
        "general.advanced.log.range",
        "Time range"
    )
    let discardArrangement = SettingsControl(
        "general.advanced.discard_arrangement",
        "Discard Saved Window Arrangement"
    )
    let resetAll = SettingsControl(
        "general.advanced.reset_all",
        "Reset All Settings…"
    )
    let restoreBackup = SettingsControl(
        "general.advanced.backup.restore",
        "Restore from Backup…"
    )
}
