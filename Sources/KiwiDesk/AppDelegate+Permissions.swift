import AppKit
import KiwiDeskCore

/// Permission transitions and the Start Tiling gate (#2050): a
/// granted permission waits for the user's press, recorded in
/// `TilingConsent`, and `startManaging()` is the one door to
/// `core.start()`.
extension AppDelegate {
    func permissionChanged(_ trusted: Bool) {
        if !trusted {
            // Revoked mid-session: pause management and reopen at
            // the grant step.
            core.stop()
            syncCoreHold()
            notifyPermissionLost()
            showOnboarding(at: .grant)
            return
        }
        syncCoreHold()
        // A grant alone is not a request to tile (#2050); the door
        // refuses until Start Tiling was pressed.
        guard hasStartedTiling else { return }
        // Float wizard above windows being tiled (#331).
        floatOnboardingAboveManagedWindows()
        startManaging()
    }

    /// The one door to `core.start()`: refuses until the
    /// permission is granted and Start Tiling was pressed.
    func startManaging() {
        guard coreHold == .running else { return }
        core.start()
    }

    var hasStartedTiling: Bool {
        TilingConsent.hasStarted(isTrusted: permissions.isTrusted)
    }

    var coreHold: CoreHold {
        .of(
            isTrusted: permissions.isTrusted,
            hasStarted: hasStartedTiling
        )
    }

    /// Records the press and starts management; the tour stays on
    /// its grant page to narrate the arrangement.
    func startTiling() {
        guard coreHold == .notStarted else { return }
        TilingConsent.markStarted()
        syncCoreHold()
        floatOnboardingAboveManagedWindows()
        startManaging()
    }

    /// Pushes the one `coreHold` reading to every surface.
    func syncCoreHold() {
        let hold = coreHold
        onboardingModel.isTrusted = hold != .permissionMissing
        onboardingModel.hasStartedTiling = hold == .running
        statusItem?.setWarning(hold == .permissionMissing)
        statusItem?.setTilingIdle(hold == .notStarted)
        dashboardIfCreated?.setCoreHold(hold)
    }
}
