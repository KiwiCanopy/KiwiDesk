import KiwiDeskCore

/// A write of the live profile from outside Settings, which Core
/// announces through `onLiveProfileWritten` — the tour's look
/// (#1720), a bar menu's row (#1518), a Space added to or removed
/// from the profile by the bar's Delete, `create_space` /
/// `delete_space` with `profile`, or Settings ▸ Spaces' own add
/// button (#1790). profiles.md rules the draft policy.
extension SettingsModel {
    /// A clean draft re-reads. A dirty one takes a `persisted`
    /// edit on both sides of its diff, so the change is neither
    /// lost at the next Save nor counted as the user's — and on a
    /// leaf the draft had itself staged, the write, the newer act,
    /// wins — and nothing of an edit no file took, which lasts the
    /// session as the tour's does. A stored profile's draft is
    /// another file, which the write did not reach.
    func adoptLiveWrite(_ edit: LiveProfileEdit, persisted: Bool) {
        guard target == .live else { return }
        guard isDirty else {
            reload()
            return
        }
        guard persisted else { return }
        suppressDirty = true
        config.apply(edit)
        cleanConfig.apply(edit)
        // The write reached the base and other profiles, which the
        // checklist's stored table reads (#1827).
        if case .dropSpaceShortcuts = edit {
            ruleReachStored = core.ruleReachSnapshot()
        }
        suppressDirty = false
        recomputeDirty()
    }
}
