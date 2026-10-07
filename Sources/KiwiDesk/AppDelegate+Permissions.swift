import AppKit
import KiwiDeskCore

/// Permission transitions and the Start Tiling gate (#2050): a
/// granted permission waits for the user's press, and every
/// surface offering the press reads the one `TilingConsent`
/// answer.
extension AppDelegate {
    func permissionChanged(_ trusted: Bool) {
        onboardingModel.isTrusted = trusted
        // Keep an already-open dashboard's paused banner in sync.
        dashboardIfCreated?.setPermissionPaused(!trusted)
        if trusted, !hasStartedTiling {
            // A grant is not a request to tile (#2050).
            showTilingIdle()
        } else if trusted {
            statusItem?.setWarning(false)
            // Float wizard above windows being tiled (#331).
            floatOnboardingAboveManagedWindows()
            startManaging()
        } else {
            // Revoked mid-session: pause management and reopen at grant step.
            // An idle session never started the core (#2050).
            if hasStartedTiling { core.stop() }
            setTilingIdle(false)
            statusItem?.setWarning(true)
            notifyPermissionLost()
            showOnboarding(at: .grant)
        }
    }

    func startManaging() {
        statusItem?.setWarning(false)
        core.start()
    }

    var hasStartedTiling: Bool {
        TilingConsent.hasStarted(isTrusted: permissions.isTrusted)
    }

    /// Records the press and starts management; the tour stays on
    /// its grant page to narrate the arrangement.
    func startTiling() {
        guard permissions.isTrusted, !hasStartedTiling else { return }
        TilingConsent.markStarted()
        setTilingIdle(false)
        floatOnboardingAboveManagedWindows()
        startManaging()
    }

    /// Trusted but not started: no warning, an idle mark.
    func showTilingIdle() {
        statusItem?.setWarning(false)
        setTilingIdle(true)
    }

    /// Moves every idle surface together.
    func setTilingIdle(_ idle: Bool) {
        onboardingModel.hasStartedTiling = hasStartedTiling
        statusItem?.setTilingIdle(idle)
        dashboardIfCreated?.setTilingIdle(idle)
    }
}
