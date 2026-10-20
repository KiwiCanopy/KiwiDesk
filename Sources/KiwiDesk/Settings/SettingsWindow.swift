import AppKit

/// The Settings window. It accepts mouse-moved events, which hover
/// focus needs to hear the pointer leave it (#2378, #2381), except
/// while a window hangs from it: the flag breaks SwiftUI
/// hover in a popover over it (#2501; Apple DTS, developer forums
/// thread 736594). Derived from the children, never set and reset;
/// a popover is the one child it gets — sheets and alerts attach
/// as sheets.
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

    /// Takes mouse-moved events only while nothing hangs from it.
    func syncMouseMoves() {
        acceptsMouseMovedEvents = childWindows?.isEmpty ?? true
    }
}
