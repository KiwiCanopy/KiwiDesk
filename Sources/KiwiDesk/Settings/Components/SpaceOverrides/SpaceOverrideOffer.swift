import KiwiDeskCore

/// Controls visibility of the per-space override affordance
/// (#678 8c, `ShortcutsCapabilityUnlockTests`). One override
/// anywhere unlocks EVERY space row (a list-wide predicate, never
/// per-row `count > 0`), the unlock reaches this list and nothing
/// else, and the mode never changes what runs — saved overrides
/// keep resolving in Simple. HIDDEN rather than greyed when
/// withheld (owner ruling 2026-08-04): mode-withheld surface is
/// absent everywhere in this window, since the mode adds surface
/// rather than expanding it.
enum SpaceOverrideOffer {
    /// Offered in Power User mode or when any space has existing overrides
    /// (#678 8c).
    static func isOffered(
        mode: SettingsMode,
        settings: TilingSettings,
        spaces: [SpaceID]
    ) -> Bool {
        if mode == .powerUser { return true }
        return spaces.contains {
            settings.overrideFieldCount(for: $0) > 0
        }
    }
}
