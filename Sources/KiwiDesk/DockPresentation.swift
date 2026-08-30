import AppKit

/// Activates and presents windows in front of other apps while remaining in
/// permanent `.accessory` mode (#89).
extension NSApplication {
    /// Brings a window fully to the front from accessory mode (#89).
    @MainActor func forceFront(_ window: NSWindow) {
        // `orderFrontRegardless` shows window while process is inactive.
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        activate(ignoringOtherApps: true)
    }
}
