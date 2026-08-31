import KiwiDeskCore

/// Controls visibility of per-space override affordance in spaces list
/// (#678 8c, `ShortcutsCapabilityUnlockTests`).
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
