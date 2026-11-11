import KiwiDeskCore

/// Catalog declarations for the Shortcuts destination and its
/// three parts (#3184).

struct ShortcutsControls: Sendable {
    /// Layer definition and switching, a collapsible card (#2654),
    /// declared with its static-label rows so a hit on one opens
    /// it after the user shut it.
    let layersCard = SettingsDrawer(
        "shortcuts.section.layers",
        "Layers",
        children: LayersControls()
    )
    /// The edited layer's key sequences, a collapsible card under
    /// Layers (#1871).
    let keySequencesCard = SettingsDrawer(
        "shortcuts.section.key_sequences",
        "Key sequences"
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
    /// The Pocket card (#2680).
    let pocketCard = SettingsControl(
        "shortcuts.section.pocket",
        "Pocket"
    )
    /// Its add row, where an empty Pocket's row of the same words
    /// lands (#2941).
    let pocketAppAdd = SettingsControl(
        "shortcuts.pocket_app.add",
        "Give an app its own Pocket key…"
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
    /// The directional Maximize rows (#3062), anchors for the
    /// Layout Defaults captions' links.
    let maximizeHeightBinding = SettingsControl(
        "keybinding.maximize_height",
        "Maximize Height"
    )
    let maximizeWidthBinding = SettingsControl(
        "keybinding.maximize_width",
        "Maximize Width"
    )
    let inactiveShortcuts = SettingsControl(
        "shortcuts.section.inactive",
        "Inactive shortcuts"
    )
    let luaBindings = SettingsDrawer(
        "shortcuts.advanced.title",
        "Lua bindings"
    )
    /// The Mouse & Trackpad part (#3184) with its settings, then its
    /// groups. A drawer no disclosure draws: a hit on a setting
    /// "opens" it by picking the part (`ShortcutsSegmentTests` ▸
    /// `hitPicksThePart`).
    let gestures = SettingsDrawer(
        "shortcuts.gestures.title",
        "Mouse & Trackpad",
        children: GesturesControls()
    )
    let gesturesOnWindows = SettingsControl(
        "shortcuts.gestures.group.windows",
        "On your windows"
    )
    let gesturesModifier = SettingsControl(
        "shortcuts.gestures.group.modifier",
        "Holding a modifier"
    )
    let gesturesOnShelf = SettingsControl(
        "shortcuts.gestures.group.shelf",
        "On the KiwiShelf"
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
    let longSwipes = SettingsControl(
        "shortcuts.gestures.scroll.long_swipes",
        "Long swipes move more windows"
    )
    let stepDistance = SettingsControl(
        "shortcuts.gestures.scroll.step_distance",
        "Travel per window"
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
