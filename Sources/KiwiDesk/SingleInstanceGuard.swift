import AppKit
import KiwiDeskCore

/// Second-launch path (#196): another process holds the
/// single-instance lock. Surface the running instance when it
/// is identifiable; a bundled (.app) launch that can't be
/// surfaced gets a notice dialog. Either way the verdict goes
/// to stderr first — a terminal launch would otherwise look
/// hung while a dialog waits somewhere behind other windows —
/// and the process exits non-zero so scripts can tell "didn't
/// start" from "ran and quit". Never force-kills a wedged
/// instance — the user decides that.
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
        // Menu bar app: without a raised policy the modal
        // would open behind everything (cf. onboarding in
        // main.swift).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    exit(1)
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
