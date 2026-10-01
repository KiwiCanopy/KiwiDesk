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

    /// `save_profile` also wrote which Spaces exist and their pins
    /// (#1790): a clean draft re-reads; a dirty one moves its
    /// baseline onto the written list and pins, and takes them into
    /// the draft too where it had not edited them.
    func adoptCapturedSpaces() {
        guard target == .live else { return }
        guard isDirty else {
            reload()
            return
        }
        let live = core.capturedSpaces.map(\.id)
        let pins = core.capturedSpacePins
        if config.spaces == cleanConfig.spaces { config.spaces = live }
        if config.spacePins == cleanConfig.spacePins {
            config.spacePins = pins
        }
        cleanConfig.spaces = live
        cleanConfig.spacePins = pins
        recomputeDirty()
    }
}
