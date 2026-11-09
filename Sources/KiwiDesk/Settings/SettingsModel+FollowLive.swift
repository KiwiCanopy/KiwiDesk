import KiwiDeskCore

/// An open live draft follows the live settings (#3098).
extension SettingsModel {
    /// The one door for a live settings change under an open
    /// window: the controls follow, then the pill asks Core again,
    /// so both read one moment.
    func liveSettingsMoved() {
        followLive()
        refreshUnsavedLive()
    }

    /// The live settings moved under an open window: every leaf the
    /// draft has not edited — one equal to its baseline's — takes
    /// live, an edited leaf keeps the user's value, and the baseline
    /// moves onto live, so the draft's diff stays the user's edits
    /// A stored profile's draft is another file; a draft whose edits
    /// the decoder refuses over live stays as it is.
    func followLive() {
        guard target == .live else { return }
        let live = core.tiler.settings
        let base = cleanConfig.settings
        guard live != base,
            let next = config.settings.rebasedIfDecodable(
                from: base,
                onto: live
            )
        else { return }
        let wasSuppressed = suppressDirty
        suppressDirty = true
        config.settings = next
        cleanConfig.settings = live
        suppressDirty = wasSuppressed
        recomputeDirty()
    }
}
