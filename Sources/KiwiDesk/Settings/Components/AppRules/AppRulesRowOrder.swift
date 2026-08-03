import KiwiDeskCore

/// What the App Rules area declares about its own rendering
/// (turn 14a of the redesign, #678 Phase 3).
///
/// **It declares one thing, and deliberately not an order
/// list.** The other census-rendered areas hold `[SettingKey]`
/// lists because the census records placement but not display
/// order, so a `ForEach` needs somewhere to read the order from.
/// This area has no such `ForEach`: its repeating unit is the
/// user's app list, not a static set of settings, and one census
/// setting draws a row per app. An order list here would be a
/// second copy of `SettingKey.allCases.filter { area ==
/// .appRules && tier == … }` — derivable from the census, read
/// by nothing but its own parity test, and maintained so that
/// test could compare the copy against what it was copied from.
///
/// So the census is the sole record of these rows for the
/// placement table and for search, and what stays here is the
/// fact a reader of `gui.md`'s census promise needs: editing the
/// census moves nothing on this screen.
enum AppRulesRowOrder {
    /// Containers this area draws with a bespoke view rather
    /// than a `ForEach` over an order list. Data, not prose, so
    /// a second container going bespoke has to edit this set —
    /// which `AppRulesCensusRenderTests` asserts against the
    /// tree rather than against a restatement of it, so a
    /// container that *stops* being bespoke reds too.
    ///
    /// The same shape, and the same stated weakness, as the
    /// Shortcuts area's app list, layer strip and raw-Lua drawer
    /// (`ShortcutsRowOrder.bespokeContainers`).
    static let bespokeContainers: Set<SettingsContainer> = [
        .rulesPerApp
    ]
}
