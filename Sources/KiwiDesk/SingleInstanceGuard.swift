import AppKit
import KiwiDeskCore

/// The status a second launch reports when the lock is held.
///
/// **Zero, and that is load-bearing (#1068).** Declining to
/// start because another instance already holds the lock is a
/// job correctly done, not a failure — and launchd reads the
/// difference. The service plist carries
/// `KeepAlive { SuccessfulExit: false }`, which exists so a
/// deliberate quit stays quit while a crash is restarted (#341,
/// `ServiceManager.plist`). Reporting failure here put
/// "already running" in the crash bucket: `RunAtLoad` started a
/// second instance beside a running one, that instance bowed
/// out non-zero, launchd called it a crash and respawned it one
/// throttle later — forever, each attempt activating the
/// running app and taking the user's focus with it.
///
/// So the exit code answers "did this process fail?", and the
/// answer is no. What it no longer answers is "did a new
/// instance start?" — the stderr line above carries that, and
/// nothing in `scripts/` reads the status (checked #1068).
let secondLaunchExitStatus: Int32 = 0

/// Second-launch path (#196): another process holds the
/// single-instance lock. Surface the running instance when it
/// is identifiable; a bundled (.app) launch that can't be
/// surfaced gets a notice dialog. Either way the verdict goes
/// to stderr first — a terminal launch would otherwise look
/// hung while a dialog waits somewhere behind other windows.
/// Never force-kills a wedged instance — the user decides that.
///
/// Exits `secondLaunchExitStatus`; read its doc before changing
/// the value, which launchd's respawn policy depends on.
@MainActor
func surfaceRunningInstanceAndExit() -> Never {
    fputs(
        "KiwiDesk: already running — exiting.\n",
        stderr
    )
    let surfaced = activateRunningInstance()
    // The dialog is a Finder-launch affordance only: a bare
    // dev binary has a terminal reading the stderr line, and
    // a modal it never sees would read as a hang.
    if !surfaced, Bundle.main.bundleIdentifier != nil {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L(
            "app.already_running.title",
            "KiwiDesk Is Already Running"
        )
        alert.informativeText = L(
            "app.already_running.message",
            "Another KiwiDesk instance is already managing "
                + "your windows, so this one will quit."
        )
        // The one place KiwiDesk leaves `.accessory`, and it is
        // safe precisely because there is no way back from here:
        // the process exits a few lines down, so no
        // window can outlive the promotion and strand the app
        // `.regular` the way the old promote/demote pair did.
        // Without it a menu-bar app's modal opens behind
        // everything and the second launch looks like a no-op.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    exit(secondLaunchExitStatus)
}

/// Bring the other instance forward. Fails for bare dev
/// binaries: without a bundle ID `NSRunningApplication`
/// cannot find them.
@MainActor
private func activateRunningInstance() -> Bool {
    guard let bundleID = Bundle.main.bundleIdentifier else {
        return false
    }
    let mine = ProcessInfo.processInfo.processIdentifier
    let others = NSRunningApplication.runningApplications(
        withBundleIdentifier: bundleID
    ).filter { $0.processIdentifier != mine }
    guard let running = others.first else { return false }
    return running.activate(options: [])
}
