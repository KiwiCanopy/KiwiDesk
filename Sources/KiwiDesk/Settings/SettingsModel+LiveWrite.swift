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
        suppressDirty = false
        recomputeDirty()
    }

    /// A gone Space's shortcuts left the base and every profile
    /// (#1827), so a draft of ANY target takes it: a clean one
    /// re-reads, a dirty one drops the rows on both sides of its
    /// diff and re-reads the stored tables its Save diffs against,
    /// or that Save would write the rows back.
    func adoptShortcutDrop(_ spaces: Set<SpaceID>) {
        guard isDirty else {
            reload()
            return
        }
        suppressDirty = true
        config.layers = config.layers.removingRows(naming: spaces).layers
        cleanConfig.layers =
            cleanConfig.layers.removingRows(naming: spaces).layers
        if profileEditingBaseLayers != nil {
            profileEditingBaseLayers = core.baseKeyLayers()
        }
        ruleReachStored = core.ruleReachSnapshot()
        suppressDirty = false
        recomputeDirty()
    }
}
