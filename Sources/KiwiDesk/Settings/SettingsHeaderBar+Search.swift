import KiwiDeskCore

/// Search context builder for SettingsHeaderBar (#678).
extension SettingsHeaderBar {
    /// Constructs SettingsSearchContext from state already in
    /// memory — nothing on the search path touches AX, the
    /// session or the filesystem (spec 11a). Palettes are absent
    /// by type; the argument lives on the Kind enum.
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
