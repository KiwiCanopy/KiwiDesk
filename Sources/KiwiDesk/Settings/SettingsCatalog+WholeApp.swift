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
    /// Desktop-specific profile bindings drawer (#678 turn 13a),
    /// declared with its one static child so a hit on the switch
    /// cue's row opens it (#2142, #1250).
    let desktops = SettingsDrawer(
        "desktops.title",
        "Profiles per macOS Desktop",
        children: DesktopsControls()
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

/// Profiles ▸ Desktops rows a search can name — the binding rows'
/// labels are per-Desktop, so only the switch cue is here (#2142).
struct DesktopsControls: Sendable {
    let switchCue = SettingsControl(
        "desktops.cue",
        "Show the Desktop's number after a switch"
    )
}

struct ShortcutsControls: Sendable {
    /// Layer definition and switching card. A `SettingsControl`,
    /// not a `SettingsDrawer`: since the 2026-08-04 owner ruling
    /// the card is always open when shown at all and withholds
    /// itself entirely when not (`LayersCard`) — a drawer
    /// declaration would promise a disclosure that no longer
    /// exists.
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
    /// The Desktop families' offer in each group (#1125): the
    /// door to a capability the rows themselves are withheld
    /// behind, and — the rows carrying dynamic labels no search
    /// index can name — the only one search can offer either.
    let focusDesktops = SettingsDrawer(
        "shortcuts.desktops.focus",
        "Go to a macOS Desktop"
    )
    let moveWindowsDesktops = SettingsDrawer(
        "shortcuts.desktops.move",
        "Move windows to a macOS Desktop"
    )
    /// The Track families' door (#1440) — their only
    /// search-reachable name, the rows' labels being dynamic.
    let moveWindowsTracks = SettingsDrawer(
        "shortcuts.tracks.move",
        "Move windows in the track layout"
    )
    let sizeFloat = SettingsControl(
        "shortcuts.section.size_float",
        "Size & float"
    )
    let openApplications = SettingsControl(
        "shortcuts.section.open_applications",
        "Open applications"
    )
    /// Open applications ▸ KiwiDesk's two rows, keyed on their
    /// census label keys (the `L()` sites are `KeybindingCatalog`'s)
    /// so a hit lands on the row (#1520).
    let showShortcutsBinding = SettingsControl(
        "keybinding.show_shortcuts",
        "Show shortcuts panel"
    )
    let openSettingsBinding = SettingsControl(
        "keybinding.open_settings",
        "Open Settings"
    )
    let inactiveShortcuts = SettingsControl(
        "shortcuts.section.inactive",
        "Inactive shortcuts"
    )
    let luaBindings = SettingsDrawer(
        "shortcuts.advanced.title",
        "Lua bindings"
    )
    /// The Mouse & trackpad drawer (#1726), declared with its
    /// settings so a search hit on either opens it.
    let gestures = SettingsDrawer(
        "shortcuts.gestures.title",
        "Mouse & trackpad",
        children: GesturesControls()
    )
}

/// Shortcuts ▸ Mouse & trackpad rows, keyed on their census label
/// keys (moved from Behavior ▸ Mouse with #1726).
struct GesturesControls: Sendable {
    let scrollPan = SettingsControl(
        "shortcuts.gestures.scroll.pan",
        "Scroll through windows"
    )
    let longSwipes = SettingsControl(
        "shortcuts.gestures.scroll.long_swipes",
        "Long swipes move more windows"
    )
    let stepDistance = SettingsControl(
        "shortcuts.gestures.scroll.step_distance",
        "Travel per window"
    )
    let scrollSpaceStep = SettingsControl(
        "shortcuts.gestures.scroll.space_step",
        "Step between Spaces"
    )
    let naturalTrackpad = SettingsControl(
        "shortcuts.gestures.scroll.trackpad",
        "Trackpad"
    )
    let naturalMouse = SettingsControl(
        "shortcuts.gestures.scroll.mouse",
        "Mouse"
    )
    let mouseResize = SettingsControl(
        "behavior.mouse.resize_action",
        "Mouse resize action"
    )
    let followsFocus = SettingsControl(
        "behavior.mouse.follows_focus",
        "Move the pointer to the window that gets focus"
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
}

struct GeneralControls: Sendable {
    // Grouped by the RULE they share, not by topic: none is
    // part of a profile and none is touched by Save — the heading
    // says so, or Revert appears to undo them and does not (6b
    // audit, fourth finding).
    let appliesImmediatelyCard = SettingsControl(
        "general.applies_immediately.title",
        "Applies immediately"
    )
    /// Declared with its children so a search hit on any of
    /// them opens the drawer it lands in (#1250).
    let generalAdvanced = SettingsDrawer(
        "general.advanced.title",
        "Advanced",
        children: GeneralAdvancedControls()
    )
}

/// General ▸ Advanced rows, keyed on their census label keys so
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
