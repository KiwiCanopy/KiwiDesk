/// Home dashboard card offer and display order
/// (`HomeCardOrderTests`, #678 turn 9).
enum HomeCardOrder {
    /// THIS PROFILE, full (Power User) order.
    static let thisProfile: [SettingsDestination] = [
        .spaces, .gapsAndBorders, .bars, .colors,
        .layoutDefaults, .monitors, .behavior, .advancedColors,
    ]

    /// WHOLE APP, full (Power User) order.
    static let wholeApp: [SettingsDestination] = [
        .shortcuts, .profiles, .appRules, .general,
    ]

    /// Single offer predicate for home dashboard cards (#18, #678 turn 9).
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
