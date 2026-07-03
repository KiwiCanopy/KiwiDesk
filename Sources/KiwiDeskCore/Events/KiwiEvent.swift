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
    case windowDestroyed(WindowID)
    case windowMoved(WindowID, CGRect)
    case windowResized(WindowID, CGRect)
    case windowFocused(WindowID)
    case windowTitleChanged(WindowID, String)
    case displaysChanged([Display])
}
