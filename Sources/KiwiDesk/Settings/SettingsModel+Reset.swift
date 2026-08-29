import KiwiDeskCore

/// The reset escape hatches — thin facades over the core, with
/// the rows in `GeneralSection+Reset` (#634) and, since #1096,
/// one layer-scoped reset whose row lives in `ShortcutsHeader`.
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

    /// Replace the default layer's shortcuts with the set a
    /// FRESH install would seed for this config (#1096).
    ///
    /// The seed only ever fires into emptiness
    /// (`KiwiCore+GuiConfigSeed`), so before this there was no
    /// way for an existing install to take up an improved
    /// default — every seed change reached new installs only,
    /// and the guide's one shortcut table could describe just
    /// one of the resulting populations.
    ///
    /// Derived from the live config, not from a snapshot: the
    /// same `spaces` and `resizeStep` the seeder reads, so the
    /// result is what THIS machine would have been given rather
    /// than what some other machine was.
    ///
    /// Scoped to the default layer because that is the only one
    /// the seed ever authored — "restore defaults" has no
    /// meaning for a layer the user invented. The row is
    /// disabled elsewhere rather than hidden (`gui.md`).
    func resetShortcutsToDefaults() {
        guard
            let index = config.layers.firstIndex(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return }
        config.layers[index].bindings =
            DefaultKeybindings.bindings(
                spaces: config.spaces,
                resizeStep: Int(config.settings.resizeStep)
            )
    }

    /// How many of the default layer's rows the reset would
    /// DISCARD — the number the confirmation names, so the
    /// choice is informed rather than a bare "are you sure".
    ///
    /// A row counts as the user's when the shipped set authors
    /// no row with that combo AND that Lua: an edited combo, a
    /// re-pointed verb and an added row all qualify, while a row
    /// that merely matches a default does not.
    var shortcutsTheResetWouldDiscard: Int {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return 0 }
        let shipped = Set(
            DefaultKeybindings.bindings(
                spaces: config.spaces,
                resizeStep: Int(config.settings.resizeStep)
            )
            .map { "\($0.combo)\u{1F}\($0.lua)" }
        )
        return layer.bindings.filter {
            !shipped.contains("\($0.combo)\u{1F}\($0.lua)")
        }
        .count
    }
}
