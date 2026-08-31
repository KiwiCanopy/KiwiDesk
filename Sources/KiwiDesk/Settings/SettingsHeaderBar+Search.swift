import KiwiDeskCore

/// Search context builder for SettingsHeaderBar (#678).
extension SettingsHeaderBar {
    /// Constructs SettingsSearchContext from in-memory state.
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
