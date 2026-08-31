import KiwiDeskCore

/// Live vs saved layout drift detection for active space
/// (#123): a transient snapshot from direct comparison — never
/// latched, never routed through `isDirty`/`profileDirty`.
extension SettingsModel {
    /// Live vs saved layout modes (nil = no drift).
    struct LayoutDrift: Equatable {
        let live: LayoutMode
        let saved: LayoutMode
    }

    var hasLayoutDrift: Bool { layoutDrift != nil }

    /// Recomputes drift snapshot without reseeding `config` —
    /// safe mid-edit. The only writer of `layoutDrift`.
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
