import AppKit

/// Activates and presents windows in front of other apps while remaining in
/// permanent `.accessory` mode (#89).
extension NSApplication {
    /// Brings a window to the front from accessory mode (#89). Keeps the
    /// forcing activation: callers with no user event in hand (the tour
    /// after a login launch, the grant step on a revoked permission) are
    /// the case cooperative `activate()` may refuse (#1170);
    /// `orderFrontRegardless()` handles the inactive process case.
    @MainActor func forceFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        activate(ignoringOtherApps: true)
    }
}
