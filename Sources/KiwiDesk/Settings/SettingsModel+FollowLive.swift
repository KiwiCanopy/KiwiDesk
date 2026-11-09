import KiwiDeskCore

/// An open live draft follows the live settings (#3098).
extension SettingsModel {
    /// The one door for a live settings change under an open
    /// window: the controls follow, then the pill asks Core again,
    /// so both read one moment. Owed by every caller that has moved
    /// the live settings or finds them moved; idempotent.
    func liveSettingsMoved() {
        followLive()
        refreshUnsavedLive()
    }

    /// The live settings moved under an open window: every leaf the
    /// draft has not edited — one equal to its baseline's — takes
    /// live, an edited leaf keeps the user's value, and the baseline
    /// moves onto live, so the draft's diff stays the user's edits
    /// alone and a session-only value is the pill's live row, never
    /// an edit. Stays as it is: a stored profile's draft (another
    /// file), a stale page (#1393, whose Save refuses), a draft
    /// with sync questions open (their baseline is the other Mac's
    /// value, #2450), and one whose edits the decoder refuses over
    /// live.
    func followLive() {
        guard target == .live, !draftStale, sync.conflicts.isEmpty
        else { return }
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
