import CoreGraphics
import Foundation

/// System events observed and emitted by the `EventLoop`.
public enum KiwiEvent: Sendable {
    case appLaunched(pid: pid_t, name: String)
    case appTerminated(pid: pid_t)
    case windowCreated(ManagedWindow)
    /// Window left layout (distinguishes user minimize from window close).
    case windowDestroyed(WindowID, wasMinimized: Bool)
    /// Window hidden because its owner app hid — its own case,
    /// not a `windowDestroyed` flag: the public reason must not
    /// say `closed` (`WindowGoneReason.hidden`), and the
    /// close-return raise stands down, since macOS picks the next
    /// frontmost itself on a hide (#913).
    case windowHidden(WindowID)
    case windowMoved(WindowID, CGRect)
    case windowResized(WindowID, CGRect)
    case windowFocused(WindowID)
    case windowTitleChanged(WindowID, String)
    /// Window float classification changed (`EventLoop.reconcile`).
    case windowFloatChanged(WindowID, isFloating: Bool)
    /// Window native fullscreen state changed.
    case windowFullscreenChanged(WindowID, isFullscreen: Bool)
    /// Native tab group active window ID switched in place
    /// (`TabReconciler`, #308).
    case windowRekeyed(WindowID, WindowID)
    case displaysChanged([Display])
    /// Active Mission Control desktop changed (`NativeSpaces`).
    case desktopChanged

    /// Whether event represents a window hide drop
    /// (`EventLoop.closeReturnRaiseStandsDown`, `OwnDialogFocusTests`,
    /// `HiddenAppRaiseTests`, #913, #935).
    public var isHideDrop: Bool {
        if case .windowHidden = self { return true }
        return false
    }

    /// Removed window ID for destroy events (#1007).
    public var goneWindowID: WindowID? {
        if case .windowDestroyed(let id, _) = self { return id }
        return nil
    }
}
