import AppKit

// KiwiDesk runs as a menu bar app (no Dock icon). The activation
// policy is raised to .regular temporarily while the onboarding
// window is visible.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
