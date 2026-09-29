import KiwiDeskCore

/// A setting written into the live profile from outside Settings —
/// a bar menu's row (#1518), the #1720 shape.
extension SettingsModel {
    /// A clean draft re-reads; a dirty one takes the same edit on
    /// both sides of its diff, so the change is neither lost at the
    /// next Save nor counted as the user's. A stored profile's
    /// draft is another file, which the write did not reach.
    func adoptLiveWrite(_ edit: (inout TilingSettings) -> Void) {
        guard target == .live else { return }
        guard isDirty else {
            reload()
            return
        }
        suppressDirty = true
        edit(&config.settings)
        edit(&cleanConfig.settings)
        suppressDirty = false
        recomputeDirty()
    }
}
