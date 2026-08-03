import KiwiDeskCore

/// The App Rules area's display order (turn 14a of the
/// redesign, #678 Phase 3). The census owns *placement* — which
/// container and tier each row sits in — but records no display
/// order, so the renderer declares it here as data.
///
/// **This area's list is BESPOKE**, and the distinction matters
/// before anyone edits these lists expecting the screen to
/// move. The census's unit is a SETTING, and here one setting
/// draws a row per APP: `appRules` and `floatRules` are two
/// facets of one sentence, repeated once per app that has a
/// rule, with the add action and the delete action riding the
/// same list. So there is no `ForEach` over an order list to
/// reorder — `AppRulesSection` walks the user's apps, not the
/// census — and these lists exist so the census still records
/// the rows for the placement table and for search, with
/// `AppRulesCensusRenderTests` holding their MEMBERSHIP.
///
/// The same shape, and the same stated weakness, as the
/// Shortcuts area's app list, layer strip and raw-Lua drawer
/// (`ShortcutsRowOrder.bespokeContainers`).
enum AppRulesRowOrder {
    /// Containers this area draws with a bespoke view rather
    /// than a `ForEach` over an order list. Data, not prose, so
    /// a second container going bespoke has to edit this set —
    /// which the render guard asserts over, and the limitation
    /// cannot quietly widen.
    static let bespokeContainers: Set<SettingsContainer> = [
        .rulesPerApp
    ]

    /// The per-app sentence, at rest: which space the app opens
    /// in, whether it floats, and the two actions that add and
    /// remove a row.
    static let rulesAtRest: [SettingKey] = [
        .appRules(.appRules),
        .appRules(.floatRules),
        .appRules(.appRulesAdd),
        .appRules(.appRulesDelete),
    ]

    /// The title patterns, which surface only once the float
    /// facet is "floats when titled…" — one interaction away
    /// from the row, which is what `.showMore` means here. They
    /// are chips UNDER the sentence rather than a drawer beside
    /// it, because they qualify the facet that revealed them.
    static let rulesShowMore: [SettingKey] = [
        .appRules(.floatRulesPattern)
    ]
}
