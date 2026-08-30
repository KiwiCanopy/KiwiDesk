import KiwiDeskCore

/// Rendering declarations for the App Rules area (#678).
enum AppRulesRowOrder {
    /// Containers drawn via bespoke views rather than static order lists
    /// (`AppRulesCensusRenderTests`, `ShortcutsRowOrder.bespokeContainers`).
    static let bespokeContainers: Set<SettingsContainer> = [
        .rulesPerApp
    ]
}
