import AppKit
import KiwiDeskCore

/// Status reported on duplicate launch; 0 prevents launchd
/// respawn loops: `KeepAlive { SuccessfulExit: false }` restarts
/// a crash, and a non-zero "already running" landed in the crash
/// bucket — respawned forever, stealing focus each attempt
/// (`ServiceManager.plist`, #341, #1068). The exit code answers
/// "did this process fail?"; the stderr line answers "did a new
/// instance start?".
let secondLaunchExitStatus: Int32 = 0

/// Activates running instance and exits when lock is held
/// (`main.swift`, #196).
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
