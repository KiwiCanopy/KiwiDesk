import KiwiDeskCore

/// Evaluates visibility and gating rules for the Monitors settings area
/// (#678 Phase 3, turn 13b, `ShortcutsGates.onlyDefaultLayer`, `gui.md`,
/// `MonitorsGateTests`).
struct MonitorsGates {
    /// Whether dashboard is editing stored profile rather than live config
    /// (#18).
    let editingStoredProfile: Bool
    /// Whether edit target's displays are currently attached.
    let placementEditable: Bool
    /// Whether any space is pinned to a currently disconnected display.
    let hasOrphanedPins: Bool

    /// Reason why a control or card is withheld from view.
    enum InertReason: Hashable {
        case pictureIsDrawable
        case noOrphanedPins
    }

    /// Condition corresponding to `.monitorsDisconnected`.
    var monitorsDisconnected: Bool {
        editingStoredProfile && !placementEditable
    }

    /// Evaluates inert reason for setting key (`everyGatedRowIsResolved`).
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .monitors(.placementUnavailable):
            return monitorsDisconnected ? nil : .pictureIsDrawable
        case .monitors(.orphanPinClear):
            return hasOrphanedPins ? nil : .noOrphanedPins
        default:
            assertionFailure(
                "unhandled Monitors gate: \(key.id)"
            )
            return nil
        }
    }

    /// Gated setting keys resolved by this type (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .monitors(.placementUnavailable),
        .monitors(.orphanPinClear),
    ]

    /// Gated setting keys resolved outside this type.
    static let resolvedElsewhere: Set<SettingKey> = []
}
