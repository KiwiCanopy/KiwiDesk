import KiwiDeskCore

/// A write of the live profile from outside Settings, which Core
/// announces through `onLiveProfileWritten` — the tour's look
/// (#1720), a bar menu's row (#1518), a Space added to or removed
/// from the profile by the bar's Delete, `create_space` /
/// `delete_space` with `profile`, or Settings ▸ Spaces' own add
/// button (#1790), and an AI app's `keep_settings` (#1685).
/// profiles.md rules the draft policy.
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

    /// A top-up appended rows to the base layer, which every
    /// profile inherits, so a draft of ANY target takes them: a
    /// clean one re-reads, a dirty one adds the rows on both sides
    /// of its diff, or its Save would drop them.
    func adoptShortcutAdd(_ rows: [KeyBinding]) {
        guard isDirty else {
            reload()
            return
        }
        suppressDirty = true
        Self.appendToDefault(rows, in: &config.layers)
        Self.appendToDefault(rows, in: &cleanConfig.layers)
        if profileEditingBaseLayers != nil {
            profileEditingBaseLayers = core.baseKeyLayers()
        }
        ruleReachStored = core.ruleReachSnapshot()
        suppressDirty = false
        recomputeDirty()
    }

    /// Appends `rows` to the default layer, skipping a row whose
    /// action that layer already runs.
    private static func appendToDefault(
        _ rows: [KeyBinding],
        in layers: inout [KeyLayer]
    ) {
        guard let index = layers.firstIndex(where: { $0.isDefault }) else {
            return
        }
        let bound = Set(layers[index].bindings.map(\.lua))
        layers[index].bindings.append(
            contentsOf: rows.filter { !bound.contains($0.lua) }
        )
    }
}
