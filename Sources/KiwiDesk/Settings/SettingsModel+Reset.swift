import KiwiDeskCore

/// The two reset escape hatches (#634) — thin facades over the
/// core; the rows live in `GeneralSection+Reset`.
extension SettingsModel {
    /// Tier 1. No model/dirty interaction at all: the snapshots
    /// are not part of the edited `GuiConfig`, so nothing staged
    /// changes and nothing needs reloading.
    func discardSavedArrangement() {
        core.discardSavedArrangement()
    }

    /// Tier 2: reset the core, then re-read the fresh seed.
    /// Staged edits vanish with the state they edited — the
    /// confirmation dialog says so, and `reload` drops a
    /// stored-profile target whose file went with the reset.
    func resetAllSettings() {
        core.resetAllSettings(trash: KiwiCore.moveToTrash)
        reload()
    }
}
