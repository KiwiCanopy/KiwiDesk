import KiwiDeskCore

/// What a Keep owes an open Settings draft (#1179).
extension SettingsModel {
    /// Moves the draft's saved BASELINE onto the layout a keep
    /// just wrote, leaving every staged edit staged (#1179).
    ///
    /// Live drafts only: a draft editing a STORED profile holds
    /// that profile's modes, and the keep wrote the ACTIVE one's
    /// — writing them in would show one profile's layout while
    /// editing another, and `saveEditedProfile` would then
    /// commit it. The retired drift path carried the same guard.
    func adoptKeptLayout() {
        guard target == .live else { return }
        let edited = SettingsDraftDiff.editedSpaceModes(
            config: config,
            cleanConfig: cleanConfig
        )
        let saved = core.savedProfileModes() ?? [:]
        for space in Set(config.spaces)
            .union(cleanConfig.spaces)
            .union(saved.keys)
        {
            cleanConfig.spaceModes[space] = saved[space]
            guard !edited.contains(space) else { continue }
            config.spaceModes[space] = saved[space]
        }
        recomputeDirty()
    }
}
