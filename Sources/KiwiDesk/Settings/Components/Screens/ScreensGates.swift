import KiwiDeskCore

/// Evaluates visibility and gating rules for the Screens area
/// (#678 Phase 3, turn 13b, `ScreensGateTests`). Every gate here
/// SURFACES rather than greys — not an exception to "grey don't
/// hide" (gui.md): a picture of unattached screens has nothing
/// to dim, so the banner takes the picture's place and says so.
/// The picture's own rows carry NO gate on purpose: one tag on
/// both the banner and the rows it replaces would declare one
/// condition with two opposite meanings.
struct ScreensGates {
    /// Whether dashboard is editing stored profile rather than live config
    /// (#18).
    let editingStoredProfile: Bool
    /// Whether edit target's screens are currently attached.
    let placementEditable: Bool
    /// Whether any space is pinned to a currently disconnected screen.
    let hasOrphanedPins: Bool

    /// Reason why a control or card is withheld from view.
    enum InertReason: Hashable {
        case pictureIsDrawable
        case noOrphanedPins
    }

    /// Condition corresponding to `.screensDisconnected`.
    var screensDisconnected: Bool {
        editingStoredProfile && !placementEditable
    }

    /// Evaluates inert reason for setting key (`everyGatedRowIsResolved`).
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .screens(.placementUnavailable):
            return screensDisconnected ? nil : .pictureIsDrawable
        case .screens(.orphanPinClear):
            return hasOrphanedPins ? nil : .noOrphanedPins
        default:
            assertionFailure(
                "unhandled Screens gate: \(key.id)"
            )
            return nil
        }
    }

    /// Gated setting keys resolved by this type (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .screens(.placementUnavailable),
        .screens(.orphanPinClear),
    ]

    /// Gated setting keys resolved outside this type.
    static let resolvedElsewhere: Set<SettingKey> = []
}
