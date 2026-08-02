/// The Shortcuts area's display order (turn 5 of the redesign,
/// #678 Phase 3). Same split as `BarsRowOrder` and
/// `ColorsRowOrder`: the census owns *placement* — which
/// container and tier each row sits in — and records no display
/// order, so the renderer declares it here as data.
///
/// `ShortcutsCensusRenderTests` pins each list against the
/// census: every `.shortcuts`-area key must appear in exactly
/// the list its placement names, so a census row added or
/// retiered without a renderer update is a red test, not a
/// silently missing control.
///
/// **These are FAMILIES, not rows.** A census case here is one
/// keybinding family — `focusDir` is the setting, and the four
/// directional rows on screen are its instances. The expansion
/// lives in `ShortcutsFamilyRows`, which switches exhaustively
/// over the same cases, so the two halves cannot drift: a family
/// added to the census must be placed in a list here AND given
/// an expansion there before it compiles and passes.
enum ShortcutsRowOrder {
    /// Focus: the four directions, then one row per live space.
    static let focusAtRest: [SettingKey] = [
        .shortcuts(.focusDir),
        .shortcuts(.goToSpace),
    ]

    /// Move windows: the directional swaps, the track verbs
    /// (authoring rows, always rendered — only meaningful in the
    /// track layout, which the caption says), then the per-space
    /// move pair.
    static let moveWindowsAtRest: [SettingKey] = [
        .shortcuts(.swapDir),
        .shortcuts(.moveWindowToTrack),
        .shortcuts(.swapWithTrack),
        .shortcuts(.moveToSpace),
        .shortcuts(.moveToSpaceFollow),
    ]

    /// Size & float: the four resize rows in grow/shrink pairs
    /// per axis, then the three state toggles.
    static let sizeAndFloatAtRest: [SettingKey] = [
        .shortcuts(.growWidth),
        .shortcuts(.shrinkWidth),
        .shortcuts(.growHeight),
        .shortcuts(.shrinkHeight),
        .shortcuts(.toggleFloating),
        .shortcuts(.toggleSticky),
        .shortcuts(.toggleDisplaySticky),
    ]

    /// Behind Size & float's disclosure: the unsupported-resize
    /// cue. Not a keybinding at all but a `TilingSettings`
    /// toggle, which is why its census case lives in the
    /// Behaviour sub-enum while its PLACEMENT names this
    /// container — the census is grouped by model subsystem and
    /// placed by area, and this row is the case that proves the
    /// two are separate axes.
    static let sizeAndFloatMore: [SettingKey] = [
        .behaviour(.resizeFeedback)
    ]

    /// Open applications: one family, expanding to a row per
    /// configured app plus the trailing "Add application".
    static let openApplicationsAtRest: [SettingKey] = [
        .shortcuts(.openApplications)
    ]

    /// App chrome rather than a workspace action, so it sits
    /// below the action groups and behind a disclosure.
    static let generalKeysMore: [SettingKey] = [
        .shortcuts(.showShortcuts)
    ]

    /// Layers: the strip itself, the selected layer's menu-bar
    /// icon, and one switch row per other layer. All three are
    /// one container — the rows that switch layers belong beside
    /// the strip that defines them, not among the action groups.
    static let layersMore: [SettingKey] = [
        .shortcuts(.layers),
        .shortcuts(.layersIcon),
        .shortcuts(.switchToLayer),
    ]

    /// The power-user escape hatch, and the Import row that only
    /// surfaces while `init.lua` holds adoptable bindings.
    static let luaBindingsMore: [SettingKey] = [
        .shortcuts(.advanced),
        .shortcuts(.import),
    ]
}
