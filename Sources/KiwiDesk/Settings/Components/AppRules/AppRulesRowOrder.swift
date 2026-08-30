import KiwiDeskCore

/// Rendering declarations for the App Rules area (#678); the census is the
/// sole record of row placement and search ordering.
enum AppRulesRowOrder {
    /// Containers drawn via bespoke views rather than static order lists
    /// (`AppRulesCensusRenderTests`, `ShortcutsRowOrder.bespokeContainers`).
    static let bespokeContainers: Set<SettingsContainer> = [
        .rulesPerApp
    ]
}
