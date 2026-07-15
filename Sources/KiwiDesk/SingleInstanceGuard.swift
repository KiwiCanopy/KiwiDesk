import AppKit
import KiwiDeskCore

/// Second-launch path (#196): another process holds the
/// single-instance lock. Surface the running instance when it
/// is identifiable; otherwise explain the exit with a notice
/// so a silent bounce isn't mysterious. Never force-kills a
/// wedged instance — the user decides that.
@MainActor
func surfaceRunningInstanceAndExit() -> Never {
    if activateRunningInstance() {
        exit(0)
    }
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = L(
        "app.already_running.title",
        "KiwiDesk Is Already Running"
    )
    alert.informativeText = L(
        "app.already_running.message",
        "Another KiwiDesk instance is already managing your "
            + "windows, so this one will quit."
    )
    // Menu bar app: without a raised policy the modal would
    // open behind everything (cf. onboarding in main.swift).
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
    exit(0)
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
