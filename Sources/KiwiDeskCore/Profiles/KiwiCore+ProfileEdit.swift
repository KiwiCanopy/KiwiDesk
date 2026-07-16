import Foundation

/// Edit-without-activating (#18/#82): the non-adopting writes
/// behind the dashboard's stored-profile edit mode, and the one
/// shared edit-session transform they apply. Split from
/// `KiwiCore+Profiles.swift` (commands + building/persisting)
/// to stay under the file-size ceiling.
extension KiwiCore {
    /// Writes the edited tiling from `config` into the stored
    /// profile `name` **without adopting it** — no change to
    /// `current`/`dirty`, no touch to live state. Edit-without-
    /// activating for the dashboard's profile dropdown (#18).
    ///
    /// The live monitor set's pins are refreshed only when the
    /// profile already covers the connected monitors; a profile
    /// whose monitors aren't attached never gets them injected
    /// (its Canvas is read-only in that case, so `spacePins` is
    /// empty here anyway).
    public func overwriteProfile(
        named name: String,
        with config: GuiConfig
    ) throws {
        var existing = try profiles.read(name: name)
        applyProfileEdits(from: config, onto: &existing)
        try profiles.write(existing)
        refreshConfigIssues()
    }

    /// Duplicates the stored profile `name` under a NEW free
    /// name derived from `requested`, carrying the pending
    /// edit-session changes — "Save copy as…" (#82). Same
    /// transform and non-adopting write as `overwriteProfile`,
    /// so live state, `current`/`dirty`, `gui.json`, and
    /// `init.lua` stay untouched. The copy inherits the
    /// source's monitor sets (including other-hardware ones)
    /// and its sparse keybinding and window-rule overrides
    /// re-diffed with the edits; the count-default flag is NOT
    /// copied (two defaults per count would be ambiguous).
    /// Built on `profiles.read` — deliberately NOT
    /// `buildProfile`, which snapshots live tiling and would
    /// drop its behavior overrides. Returns the name actually
    /// used (`_1`, `_2`, … when `requested` is taken).
    @discardableResult
    public func copyProfile(
        named name: String,
        to requested: String,
        with config: GuiConfig
    ) throws -> String {
        var copy = try profiles.read(name: name)
        applyProfileEdits(from: config, onto: &copy)
        copy.name = profiles.freeName(
            base: requested.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
        copy.isDefault = false
        try profiles.write(copy)
        return copy.name
    }

    /// The shared edit-session transform: writes the GUI
    /// model's profile-scoped fields onto `profile`. ONE
    /// definition, used by `overwriteProfile` and
    /// `copyProfile` — a second hand-mirror of this field
    /// list would drift (AGENTS.md §5).
    private func applyProfileEdits(
        from config: GuiConfig,
        onto profile: inout Profile
    ) {
        profile.settings = config.settings
        // Capture the display order from the GUI model (#75):
        // the config's `spaces` list is the profile's new
        // authoritative order.
        profile.spaces = config.spaces
        // Same dangling-reference guard as
        // `applyProfileScopedState` (#68).
        profile.fallbackSpace = config.fallbackSpace.flatMap {
            config.spaces.contains($0) ? $0 : nil
        }
        // Dense over the profile's own spaces (mirrors
        // `buildProfile`): an undeclared space reads as bsp. The
        // union with `spaceModes.keys` keeps a just-set mode even
        // if its space hasn't landed in the list yet; `spaces` is
        // profile-derived (see `overlayProfileState`), so no
        // live-only space can leak in here.
        var modes: [SpaceID: LayoutMode] = [:]
        let declared = Set(config.spaces)
            .union(config.spaceModes.keys)
        for space in declared {
            modes[space] = config.spaceModes[space] ?? .bsp
        }
        profile.spaceModes = modes
        profile.mainSpaces = config.mainSpaces.sorted {
            $0.raw < $1.raw
        }
        // Per-profile keybinding and window-rule overrides: the
        // edited modes/rules are the
        // RESOLVED sets (seeded by `overlayProfileState`);
        // store only the sparse diffs against the SAME base
        // the seed resolved onto (`baseKeyModes()` /
        // `baseAppRules()`). nil when nothing diverges — an
        // empty override is never persisted (O3/o4), and
        // gui.json itself is NOT written here. A sidecar that
        // exists but fails to decode gives no trustworthy
        // base — keep the stored overrides untouched rather
        // than capturing the whole resolved sets.
        let guiOwned = isGuiManaged
        let sidecar = guiOwned ? guiConfigStore.load() : nil
        if guiOwned, guiConfigStore.exists, sidecar == nil {
            // `profile.name` is the SOURCE here even on the
            // copy path (rename happens after the transform).
            onLog(
                "profiles: gui.json unreadable — keeping the "
                    + "stored behavior "
                    + "overrides of '\(profile.name)' unchanged"
            )
        } else {
            let base = sidecar ?? guiConfigSeed()
            profile.modes = KeyModeOverride.diff(
                base: base.modes,
                edited: config.modes
            )
            profile.appRules = AppRuleOverride.diff(
                base: sidecar?.appRules ?? globalAppRuleBase,
                edited: config.appRules
            )
            profile.floatRules = RuleListOverride.diff(
                base: sidecar?.floatRules ?? globalFloatRuleBase,
                edited: config.floatRules,
                normalizing: FloatRules.normalizedRule
            )
            // `ignoreRules` is deliberately untouched: the GUI has
            // no ignore editor, so even an inert hidden tombstone must
            // survive overwrite/copy until an external edit removes it.
        }
        let live = state.workspaces.allDisplays
            .map(\.fingerprint)
        if profile.set(matching: live) != nil {
            profile.upsert(
                MonitorSet(
                    monitors: live,
                    spaceMonitorMap: config.spacePins
                )
            )
        }
        profile.savedAt = .now
    }
}
