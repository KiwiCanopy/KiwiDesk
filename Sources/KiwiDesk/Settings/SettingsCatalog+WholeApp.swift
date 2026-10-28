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
    /// Layer definition and switching, a collapsible card (#2654),
    /// declared with its static-label rows so a hit on one opens
    /// it after the user shut it.
    let layersCard = SettingsDrawer(
        "shortcuts.section.layers",
        "Layers",
        children: LayersControls()
    )
    /// The Show & hide card: KiwiHub, KiwiShelf and KiwiVision,
    /// each a sub-group titled by its product name below.
    let showHideKeys = SettingsControl(
        "shortcuts.section.show_hide",
        "Show & hide"
    )
    /// The Show & hide card's KiwiHub sub-group (#2265).
    let kiwiHubKeys = SettingsControl(
        "kiwihub.name",
        "KiwiHub"
    )
    let focusKeys = SettingsControl(
        "shortcuts.section.focus",
        "Focus"
    )
    /// The Show & hide card's KiwiVision sub-group (#2312),
    /// titled by the product name's one key.
    let kiwiVisionKeys = SettingsControl(
        "destination.kiwivision",
        "KiwiVision"
    )
    /// The Show & hide card's KiwiShelf sub-group (#761).
    let kiwishelfKeys = SettingsControl(
        "bars.switch.kiwishelf",
        "KiwiShelf"
    )
    let moveWindows = SettingsControl(
        "shortcuts.section.move_windows",
        "Move windows"
    )
    /// The Track families' door (#1440) — their only
    /// search-reachable name, the rows' labels being dynamic.
    let moveWindowsTracks = SettingsDrawer(
        "shortcuts.tracks.move",
        "Move windows in the track layout"
    )
    /// The macOS Desktops section (#2655). Its title and its
    /// drawer's are the Desktop families' only search-reachable
    /// names, the rows' labels being dynamic.
    let desktopsSection = SettingsControl(
        "shortcuts.section.macos_desktops",
        "macOS Desktops"
    )
    /// The section's first row, the Desktop switch cue (#2142),
    /// on its census label.
    let desktopCue = SettingsControl(
        "desktops.cue",
        "Show the Desktop's number after a switch"
    )
    let desktopMoves = SettingsDrawer(
        "shortcuts.desktops.move",
        "Move windows to a macOS Desktop"
    )
    let layoutKeys = SettingsControl(
        "shortcuts.section.layout",
        "Layout"
    )
    /// Layout ▸ the cycle list and the plate's switch (#453,
    /// #2144), keyed on their census label keys so a hit lands on
    /// the row.
    let modeCycle = SettingsControl(
        "shortcuts.mode_cycle",
        "Layouts to cycle"
    )
    let modeCue = SettingsControl(
        "shortcuts.mode_cue",
        "Show the layout after cycling"
    )
    /// The collapsible card above the layer header (#2601 ▸
    /// Ruling 7, #2654): Apple's own name for these keys, as each
    /// catalog's macOS spells it.
    let modifierKeys = SettingsDrawer(
        "shortcuts.section.modifier_keys",
        "Modifier keys",
        children: ModifierKeysControls()
    )
    let sizeFloat = SettingsControl(
        "shortcuts.section.size_float",
        "Size & float"
    )
    /// The Pocket card (#2680), its capacity row (#2678) and its
    /// two placement rows on their census labels.
    let pocketKeys = SettingsControl(
        "shortcuts.section.pocket",
        "Pocket"
    )
    let pocketCapacity = SettingsControl("pocket.capacity", "Holds")
    let pocketEdge = SettingsControl("pocket.edge", "Edge")
    let pocketPosition = SettingsControl(
        "pocket.position",
        "Position along the edge"
    )
    let openApplications = SettingsControl(
        "shortcuts.section.open_applications",
        "Open applications"
    )
    /// KiwiHub's shortcuts-panel row and Open applications ▸
    /// KiwiDesk's row, keyed on their census label keys (the `L()`
    /// sites are `KeybindingCatalog`'s) so a hit lands on the row
    /// (#1520, #2265).
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

/// Shortcuts ▸ Layers rows drawn under a selected layer, keyed on
/// their census label keys (#2654).
struct LayersControls: Sendable {
    let reach = SettingsControl("app_rules.reach", "Applies to")
    let menuBarIcon = SettingsControl(
        "shortcuts.menu_bar_icon",
        "Menu bar icon"
    )
}

/// Shortcuts ▸ Modifier keys rows, keyed on their census label
/// keys so a search hit opens the card (#2654).
struct ModifierKeysControls: Sendable {
    /// The Hyper key's recorder row (#1870).
    let hyperKey = SettingsControl(
        "shortcuts.hyper_key",
        "Hyper key"
    )
    /// "Shortcuts use" (#2460).
    let shortcutBase = SettingsControl(
        "shortcuts.base",
        "Shortcuts use"
    )
    /// The sides switch (#2601).
    let modifierSides = SettingsControl(
        "shortcuts.modifier_sides",
        "Tell left and right modifiers apart"
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
    let hoverFocus = SettingsControl(
        "behavior.mouse.hover_focus",
        "Focus the window the pointer rests on"
    )
    let hoverFocusDelay = SettingsControl(
        "behavior.mouse.hover_focus_delay",
        "Hover delay"
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
