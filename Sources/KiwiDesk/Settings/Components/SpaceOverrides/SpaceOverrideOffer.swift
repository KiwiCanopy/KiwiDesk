import KiwiDeskCore

/// Whether the per-space Customize button sits on the rows at rest
/// (#678 8c, `ShortcutsCapabilityUnlockTests`). One override
/// anywhere unlocks EVERY space row (a list-wide predicate, never
/// per-row `count > 0`), and the unlock reaches this list and
/// nothing else. Each row's actions menu opens the editor either
/// way (#2654), so the button is HIDDEN rather than greyed.
enum SpaceOverrideOffer {
    static func isOffered(
        settings: TilingSettings,
        spaces: [SpaceID]
    ) -> Bool {
        spaces.contains {
            settings.spaceOverrideCount(for: $0) > 0
        }
    }
}
