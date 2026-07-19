import KiwiDeskCore

/// Live-vs-saved layout drift for the active space (#123),
/// split from SettingsModel.swift (file-size ceiling): a
/// transient snapshot from direct comparison — never latched,
/// never routed through `isDirty`/`profileDirty`.
extension SettingsModel {
    /// nil = no drift.
    struct LayoutDrift: Equatable {
        let live: LayoutMode
        let saved: LayoutMode
    }

    var hasLayoutDrift: Bool { layoutDrift != nil }

    /// Recomputes the drift snapshot without reseeding `config`
    /// — safe mid-edit; the quick menu calls it after a
    /// session-only layout switch or save. External `set_mode`
    /// (hotkey/Lua/CLI) refreshes on the next window `show()`.
    /// The only writer of `layoutDrift`.
    func refreshLayoutDrift() {
        layoutDrift = computeLayoutDrift()
    }

    /// The fresh comparison — `revert()` reads this directly
    /// (not the published snapshot) so a switch the UI hasn't
    /// caught up with still reverts.
    func computeLayoutDrift() -> LayoutDrift? {
        guard target == .live,
            let space = core.activeSpace,
            let saved = core.savedModeForActiveSpace(),
            space.mode != saved
        else { return nil }
        return LayoutDrift(live: space.mode, saved: saved)
    }
}
