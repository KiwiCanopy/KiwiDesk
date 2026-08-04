/// Which cards Home offers, in which order (#678 turn 9).
///
/// The order is the turn-9 frame's and is STABLE across mode
/// flips: Nerd inserts its cards at their slots rather than
/// appending, so a card never moves when the segment is toggled
/// — Monitors auto-promoted into Simple sits exactly where Nerd
/// shows it. `HomeCardOrderTests` pins both lists to the
/// destination groups so a thirteenth destination cannot miss
/// the grid.
enum HomeCardOrder {
    /// THIS PROFILE, full (Nerd) order.
    static let thisProfile: [SettingsDestination] = [
        .spaces, .gapsAndBorders, .bars, .colors,
        .layoutDefaults, .monitors, .behavior, .advancedColors,
    ]

    /// WHOLE APP, full (Nerd) order.
    static let wholeApp: [SettingsDestination] = [
        .shortcuts, .profiles, .appRules, .general,
    ]

    /// One offer predicate for every surface that shows or
    /// lands on a card (the grid, the selection repair, the
    /// `settingsNavigate` guard, search) — the #18 rule with
    /// the mode as its second axis. No hand-negated copies.
    ///
    /// The `displayCount` axis deliberately has NO selection
    /// repair: unplugging the second display while standing in
    /// an auto-promoted Monitors area leaves the user there —
    /// the area still exists and still edits (its own gates
    /// handle the missing geometry); only the next Home visit
    /// re-derives the card offer. Repairing here would yank the
    /// screen out from under a user mid-edit for a change they
    /// did not make in Settings.
    static func isOffered(
        _ destination: SettingsDestination,
        mode: SettingsMode,
        displayCount: Int,
        editingStoredProfile: Bool
    ) -> Bool {
        destination.isReachable(
            editingStoredProfile: editingStoredProfile
        )
            && (mode == .nerd
                || destination.area.effectiveMinimumMode(
                    displayCount: displayCount
                ) == .simple)
    }

    /// The grid's two groups under the current state.
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
