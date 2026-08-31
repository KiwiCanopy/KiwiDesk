import KiwiDeskCore

/// What the quick menu's Keep verb owes an open Settings draft
/// (#1179, condition 3).
extension SettingsModel {
    /// Moves the draft's saved BASELINE onto the layout the keep
    /// just wrote, leaving every staged edit staged.
    ///
    /// Without this the next Settings Save silently reverts the
    /// kept layout: the draft's modes seed from the saved
    /// profile, so a space the user never touched would still
    /// hold the mode the profile had BEFORE the keep, and
    /// committing the draft would write it back — the same
    /// Save-behaves-like-Revert class this issue closes, one
    /// verb along.
    ///
    /// A space the user HAS edited keeps its staged mode and
    /// stays counted as edited: the baseline moves under it, the
    /// edit does not.
    func adoptKeptLayout() {
        let edited = SettingsDraftDiff.between(
            config: config,
            cleanConfig: cleanConfig,
            luaSource: luaSource,
            cleanLuaSource: cleanLuaSource
        ).editedSpaceModes
        let saved = core.loadGuiConfig().spaceModes
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
