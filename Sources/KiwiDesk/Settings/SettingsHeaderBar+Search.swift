import KiwiDeskCore

/// The header bar's search context (#678 turn 11) — its own
/// file for the §2.1 ceiling, not for reuse.
extension SettingsHeaderBar {
    /// Everything search may consult, collected here from state
    /// already in memory (spec 11a: nothing on the search path
    /// touches AX, the session or the filesystem). Palettes are
    /// absent by type — `SettingsSearchPlace.Kind` has no case
    /// for them until an in-memory palette-name seam exists
    /// (the argument lives on the Kind enum).
    var searchContext: SettingsSearchContext {
        SettingsSearchContext(
            editingStoredProfile: model.editingStoredProfile,
            mode: model.settingsMode,
            displayCount: model.displays.count,
            spaces: model.config.spaces.map(\.raw),
            profiles: model.profileSummaries.map(\.name),
            appRules: model.config.appRules.keys.sorted()
        )
    }
}
