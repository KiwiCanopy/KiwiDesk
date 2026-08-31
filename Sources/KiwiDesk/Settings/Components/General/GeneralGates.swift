import KiwiDeskCore

/// Resolves General settings census gates (#678 turn 14b, `gui.md`).
struct GeneralGates {
    let autoStart: AutoStartStatus

    /// Reason why a General setting is inert.
    enum InertReason: Hashable {
        /// Managed by background service LaunchAgent (`AutoStartStatus`).
        case managedByService

        /// Cannot register login item with `SMAppService`.
        case cannotRegister(LoginItemUnavailable)
    }

    /// Evaluates inert reason for setting key. Order matters:
    /// cannot-register is the harder stop, and the service already
    /// launches KiwiDesk at login (`RunAtLoad`), so the login item
    /// would be a second launcher racing it (#1071). Fail-OPEN on
    /// an unowned gate: a live row the user can ignore beats a
    /// dead one they cannot explain.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .general(.startAtLogin):
            if let cause = autoStart.unavailable {
                return .cannotRegister(cause)
            }
            return autoStart.level == .atLoginWithAutoRestart
                ? .managedByService : nil
        default:
            assertionFailure(
                "unhandled General gate: \(key.id)"
            )
            return nil
        }
    }

    /// Gated keys resolved directly by `GeneralGates`. Data, so
    /// the guard asserts the split against the census — a new
    /// gated row landing in neither set reds.
    static let resolved: Set<SettingKey> = [
        .general(.startAtLogin)
    ]

    /// Gated keys resolved elsewhere in view hierarchy.
    static let resolvedElsewhere: Set<SettingKey> = []
}
