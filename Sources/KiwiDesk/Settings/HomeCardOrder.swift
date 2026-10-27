/// Home dashboard card offer and display order
/// (`HomeCardOrderTests`, #678 turn 9). The order is STABLE: a card
/// withdrawn by the #18 stored-profile axis leaves its slot, never
/// moves the others.
enum HomeCardOrder {
    /// THIS PROFILE, full order.
    static let thisProfile: [SettingsDestination] = [
        .spaces, .gapsAndBorders, .bars, .looks,
        .layoutDefaults, .screens,
    ]

    /// WHOLE APP, full order. The checklist is LAST:
    /// the tour lands a new user on it, so Home carries only
    /// return visits, and the card that is usually done is the
    /// one to orphan on the row's second line (owner and
    /// ui-designer, #1365).
    static let wholeApp: [SettingsDestination] = [
        .kiwiVision, .shortcuts, .profiles, .appRules, .ai,
        .general, .macChecklist,
    ]

    /// Single offer predicate for home dashboard cards (#18) — no
    /// hand-negated copies. Every card shows on any screen count:
    /// Screens holds the pins of absent screens (#2690).
    static func isOffered(
        _ destination: SettingsDestination,
        editingStoredProfile: Bool
    ) -> Bool {
        destination.isReachable(
            editingStoredProfile: editingStoredProfile
        )
    }

    /// Filters destination group to currently offered cards.
    static func offered(
        _ group: [SettingsDestination],
        editingStoredProfile: Bool
    ) -> [SettingsDestination] {
        group.filter {
            isOffered($0, editingStoredProfile: editingStoredProfile)
        }
    }
}
