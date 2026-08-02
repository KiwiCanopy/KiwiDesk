import AppKit
import KiwiDeskCore

// With arguments, the binary acts as the CLI and exits; the
// Homebrew cask symlinks it into PATH for exactly this.
if CommandLine.arguments.count > 1 {
    exit(runCLI(CommandLine.arguments))
}

// KiwiDesk runs as a menu bar app (no Dock icon), and holds
// `.accessory` for its whole life — content windows come forward
// through `NSApp.forceFront` rather than through a policy flip.
// See "Permanent accessory mode" in docs/design-decisions.md.
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
