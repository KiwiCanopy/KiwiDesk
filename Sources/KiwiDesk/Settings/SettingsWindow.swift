import AppKit

/// The Settings window: it takes mouse-moved events, which hover
/// focus needs (#2378), only while no window hangs from it — the flag
/// breaks hover in a popover (#2501, Apple DTS forums thread 736594).
final class SettingsWindow: NSWindow {
    override func addChildWindow(
        _ child: NSWindow,
        ordered place: NSWindow.OrderingMode
    ) {
        super.addChildWindow(child, ordered: place)
        syncMouseMoves()
    }

    override func removeChildWindow(_ child: NSWindow) {
        super.removeChildWindow(child)
        syncMouseMoves()
    }

    /// A detach AppKit makes past the override is caught here.
    override func becomeKey() {
        super.becomeKey()
        syncMouseMoves()
    }

    /// Takes mouse-moved events only while nothing hangs from it.
    func syncMouseMoves() {
        acceptsMouseMovedEvents = childWindows?.isEmpty ?? true
    }
}
