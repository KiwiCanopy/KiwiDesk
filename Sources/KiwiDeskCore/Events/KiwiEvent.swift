import CoreGraphics
import Foundation

/// System events observed by the `EventLoop`.
///
/// Consumers (window manager, GUI, later the Lua bridge) receive
/// these instead of touching AppKit/AX notifications directly.
public enum KiwiEvent: Sendable {
    case appLaunched(pid: pid_t, name: String)
    case appTerminated(pid: pid_t)
    case windowCreated(ManagedWindow)
    /// The window left the layout. `wasMinimized` separates a
    /// user minimize (forget its space; deminiaturize lands in
    /// the active space) from closing or vanishing from AX on
    /// a native Space switch (remember it, so it returns to
    /// its space when the desktop comes back).
    case windowDestroyed(WindowID, wasMinimized: Bool)
    case windowMoved(WindowID, CGRect)
    case windowResized(WindowID, CGRect)
    case windowFocused(WindowID)
    case windowTitleChanged(WindowID, String)
    /// Float detection re-evaluated a tracked window and its
    /// verdict changed (a window scanned mid-launch can report
    /// a wrong subrole once; see EventLoop.reconcile).
    case windowFloatChanged(WindowID, isFloating: Bool)
    case displaysChanged([Display])
    /// The user switched native macOS Spaces (Mission
    /// Control). Consumers query `NativeSpaces` for details.
    case nativeSpaceChanged
}
