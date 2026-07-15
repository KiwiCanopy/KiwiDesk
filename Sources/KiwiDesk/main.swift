import AppKit
import KiwiDeskCore

// With arguments, the binary acts as the CLI and exits; the
// Homebrew cask symlinks it into PATH for exactly this.
if CommandLine.arguments.count > 1 {
    exit(runCLI(CommandLine.arguments))
}

// KiwiDesk runs as a menu bar app (no Dock icon). The activation
// policy is raised to .regular temporarily while the onboarding
// window is visible.
let app = NSApplication.shared

// Single-instance guard (#196). Held at top level so the flock
// lives exactly as long as the process. Must run before the
// delegate exists: a second KiwiCore would clobber the running
// instance's IPC socket and fight it over every window.
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
