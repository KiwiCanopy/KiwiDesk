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
        let shipped = shippedDefaults
        let orphanLua = orphanLuaInDefaultLayer
        let kept = config.layers[index].bindings.filter {
            Self.survivesReset(
                $0,
                against: shipped,
                orphans: orphanLua
            )
        }
        config.layers[index].bindings = shipped + kept
    }

    /// The set a fresh install would seed for THIS config — the
    /// same `spaces` and `resizeStep` the seeder reads, so a user
    /// gets what this machine would have been given.
    private var shippedDefaults: [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: config.spaces,
            resizeStep: Int(config.settings.resizeStep)
        )
    }

    /// The Lua of every row in the default layer that targets a
    /// Space which no longer exists.
    ///
    /// Asked of `OrphanedShortcuts`, never re-derived: its own
    /// docstring rules that a third surface asking "is this
    /// binding inactive?" asks THERE, because two surfaces
    /// disagreeing about what is inactive was the whole of #820.
    ///
    /// They are stale DEFAULTS, not inventions — a fresh install
    /// with these Spaces would have none of them — so a restore
    /// drops them. #92 keeps them as holders through ordinary
    /// editing; an explicit restore is a different act.
    private var orphanLuaInDefaultLayer: Set<String> {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return [] }
        return Set(
            OrphanedShortcuts.commands(
                bindings: layer.bindings,
                spaces: config.spaces
            )
            .map(\.lua)
        )
    }

    /// How many shipped rows this install does not already have,
    /// exactly as they ship — the GAIN, and the number the
    /// confirmation leads with.
    var shortcutsTheResetWouldRestore: Int {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return 0 }
        let have = Set(
            layer.bindings.map { "\($0.combo)\u{1F}\($0.lua)" }
        )
        return shippedDefaults.filter {
            !have.contains("\($0.combo)\u{1F}\($0.lua)")
        }
        .count
    }

    /// Is there anything to restore? The button's gate: absent
    /// rather than greyed when this install already matches what
    /// KiwiDesk ships, so its presence is itself the news.
    var hasDefaultsToRestore: Bool {
        shortcutsTheResetWouldRestore > 0
            || shortcutsTheResetWouldDiscard > 0
    }

    /// Does `row` outlive a reset?
    ///
    /// Only rows the SEED AUTHORS are replaced — those are the
    /// only ones KiwiDesk provides, so they are the only ones it
    /// can restore (owner ruling). An app launcher, a Desktop row
    /// or anything else the user invented is not a "customised
    /// default"; it exists only because they made it, and a
    /// restore has no business deleting it.
    ///
    /// Two ways a row is the seed's, and both must go or the
    /// restored set is not the shipped one:
    ///
    /// - its **Lua** is a shipped verb — a default whose combo the
    ///   user moved; leaving it would double the verb.
    /// - its **combo** is a shipped chord — the seed is about to
    ///   reclaim that key, and leaving the row would put two
    ///   bindings on it, which is precisely the conflict the
    ///   restore should not manufacture. This is the case that
    ///   costs a user something real: an app shortcut parked on a
    ///   default's chord does not survive, which is why the
    ///   confirmation counts it.
    ///
    /// Combos compare through `KeyCombo`, not as text, so a
    /// hand-authored alias (`ctrl+alt+1`) counts as the same
    /// chord — the identity `digitTopUp` already uses.
    private static func survivesReset(
        _ row: KeyBinding,
        against shipped: [KeyBinding],
        orphans: Set<String>
    ) -> Bool {
        if shipped.contains(where: { $0.lua == row.lua }) {
            return false
        }
        if orphans.contains(row.lua) {
            return false
        }
        guard let combo = KeyCombo.parse(row.combo) else {
            return true
        }
        return !shipped.contains {
            KeyCombo.parse($0.combo) == combo
        }
    }

    /// How many of the user's own rows the reset would DISCARD —
    /// the number the confirmation names, so agreeing is an
    /// informed act rather than a bare "are you sure".
    ///
    /// Counts exactly what will not survive: a default whose
    /// combo was moved, and a row of the user's own parked on a
    /// chord the seed is about to reclaim. A row that merely
    /// matches a default is not "theirs", and a row that outlives
    /// the reset is not discarded — so this is neither the count
    /// of non-default rows nor the count of changes.
    var shortcutsTheResetWouldDiscard: Int {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return 0 }
        let shipped = shippedDefaults
        let orphanLua = orphanLuaInDefaultLayer
        return layer.bindings.filter { row in
            // A default — moved or not — is not the user's, and
            // its verb comes back on the shipped chord. Counting
            // it told the very population this feature is for
            // that their shortcuts were being deleted.
            if shipped.contains(where: { $0.lua == row.lua }) {
                return false
            }
            // A row for a Space that is gone is KiwiDesk's own,
            // just stale. Dropping it costs the user nothing.
            if orphanLua.contains(row.lua) { return false }
            // What is left is theirs. It is lost only if a
            // default is about to reclaim its chord.
            guard let combo = KeyCombo.parse(row.combo) else {
                return false
            }
            return shipped.contains {
                KeyCombo.parse($0.combo) == combo
            }
        }
        .count
    }
}
