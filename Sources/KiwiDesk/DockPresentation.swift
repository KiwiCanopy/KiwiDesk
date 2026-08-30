import AppKit

/// Activates and presents windows in front of other apps while remaining in
/// permanent `.accessory` mode (#89).
extension NSApplication {
    /// Brings a window to the front from accessory mode (#89). Cooperative
    /// `activate()` fails to foreground background/launchd activations;
    /// `orderFrontRegardless()` handles the inactive process case.
    @MainActor func forceFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        activate(ignoringOtherApps: true)
    }
}
