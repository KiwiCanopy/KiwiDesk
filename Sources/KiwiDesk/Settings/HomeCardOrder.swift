/// Home dashboard card offer and display order
/// (`HomeCardOrderTests`, #678 turn 9). The order is STABLE across
/// mode flips: Power User inserts its cards at their slots rather
/// than appending, so a card never moves on a segment toggle.
enum HomeCardOrder {
    /// THIS PROFILE, full (Power User) order.
    static let thisProfile: [SettingsDestination] = [
        .spaces, .gapsAndBorders, .bars, .colors,
        .layoutDefaults, .monitors, .behavior, .advancedColors,
    ]

    /// WHOLE APP, full (Power User) order. The checklist is LAST:
    /// the tour lands a new user on it, so Home carries only
    /// return visits, and the card that is usually done is the
    /// one to orphan on the row's second line (owner and
    /// ui-designer, #1365).
    static let wholeApp: [SettingsDestination] = [
        .shortcuts, .profiles, .appRules, .general, .macChecklist,
    ]

    /// Single offer predicate for home dashboard cards (#18) — no
    /// hand-negated copies. The `displayCount` axis deliberately
    /// has NO selection repair: unplugging a display must not yank
    /// the screen mid-edit; the next Home visit re-derives.
    static func isOffered(
        _ destination: SettingsDestination,
        mode: SettingsMode,
        displayCount: Int,
        editingStoredProfile: Bool
    ) -> Bool {
        destination.isReachable(
            editingStoredProfile: editingStoredProfile
        )
            && (mode == .powerUser
                || destination.area.effectiveMinimumMode(
                    displayCount: displayCount
                ) == .simple)
    }

    /// Filters destination group to currently offered cards.
    static func offered(
        _ group: [SettingsDestination],
        mode: SettingsMode,
        displayCount: Int,
        editingStoredProfile: Bool
    ) -> [SettingsDestination] {
        group.filter {
            isOffered(
                $0,
                mode: mode,
                displayCount: displayCount,
                editingStoredProfile: editingStoredProfile
            )
        }
    }
}
