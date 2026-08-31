import AppKit
import KiwiDeskCore

// CLI dispatch when arguments are supplied.
if CommandLine.arguments.count > 1 {
    exit(runCLI(CommandLine.arguments))
}

// Runs as accessory menu bar app (docs/design-decisions.md).
let app = NSApplication.shared

// Single-instance lock held for process lifetime (#196).
let instanceLock = SingleInstanceLock(
    path: SingleInstanceLock.defaultPath
)
if !instanceLock.acquire() {
    surfaceRunningInstanceAndExit()
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
