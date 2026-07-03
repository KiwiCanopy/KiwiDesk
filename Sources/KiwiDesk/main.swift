import AppKit

// With arguments, the binary acts as the CLI and exits; the
// Homebrew cask symlinks it into PATH for exactly this.
if CommandLine.arguments.count > 1 {
    exit(runCLI(CommandLine.arguments))
}

// KiwiDesk runs as a menu bar app (no Dock icon). The activation
// policy is raised to .regular temporarily while the onboarding
// window is visible.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
