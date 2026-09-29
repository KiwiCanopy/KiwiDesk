import KiwiDeskCore

/// A write of the live profile from outside Settings, which Core
/// announces through `onLiveProfileWritten` — the tour's look
/// (#1720), a bar menu's row (#1518). profiles.md rules the draft
/// policy.
extension SettingsModel {
    /// A clean draft re-reads. A dirty one takes a `persisted`
    /// edit on both sides of its diff, so the change is neither
    /// lost at the next Save nor counted as the user's — and on a
    /// leaf the draft had itself staged, the write, the newer act,
    /// wins — and nothing of an edit no file took, which lasts the
    /// session as the tour's does. A stored profile's draft is
    /// another file, which the write did not reach.
    func adoptLiveWrite(
        _ edit: (inout TilingSettings) -> Void,
        persisted: Bool
    ) {
        guard target == .live else { return }
        guard isDirty else {
            reload()
            return
        }
        guard persisted else { return }
        suppressDirty = true
        edit(&config.settings)
        edit(&cleanConfig.settings)
        suppressDirty = false
        recomputeDirty()
    }
}
