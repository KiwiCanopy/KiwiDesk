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
    /// The window left the layout because its APP hid — ⌘H,
    /// or an Electron app hiding itself as its last window
    /// closes (#913). Its own case rather than a
    /// `windowDestroyed` flag for two reasons a bool could not
    /// carry: the public `window_destroyed` reason must not say
    /// `closed` for a window that was never closed
    /// (`WindowGoneReason.hidden`), and the close-return raise
    /// must stand down — macOS picks the next frontmost app
    /// itself on a hide, and a raise racing that choice moves
    /// the user somewhere neither of them chose.
    ///
    /// The state fold is a non-minimized destroy exactly: the
    /// window keeps its remembered space and comes back to it
    /// on unhide, which is what makes the appear side classify
    /// as `returned` rather than `new`.
    case windowHidden(WindowID)
    case windowMoved(WindowID, CGRect)
    case windowResized(WindowID, CGRect)
    case windowFocused(WindowID)
    case windowTitleChanged(WindowID, String)
    /// Float detection re-evaluated a tracked window and its
    /// verdict changed (a window scanned mid-launch can report
    /// a wrong subrole once; see EventLoop.reconcile).
    case windowFloatChanged(WindowID, isFloating: Bool)
    /// A tracked window entered or left native (green-button)
    /// fullscreen. The window keeps its state slot (no destroy);
    /// only the snapshot flag flips, so the focus ring can be
    /// suppressed while it fills its own macOS Space. Emitted
    /// from the reconcile recheck, change-only.
    case windowFullscreenChanged(WindowID, isFullscreen: Bool)
    /// A managed window's tracked id changed in place, from the
    /// first id to the second. Native macOS tabs are separate
    /// `NSWindow`s sharing one frame, one on screen at a time, each
    /// with its own `CGWindowID`; when the active tab switches (or
    /// the active tab closes with siblings left), the group's single
    /// layout slot must adopt the new active id without a
    /// destroy/create pair — no new tile, no lost focus (#308).
    /// `TabReconciler` decides when to emit this from the event loop;
    /// the state fold swaps the id across every id-keyed map in place.
    case windowRekeyed(WindowID, WindowID)
    case displaysChanged([Display])
    /// The user switched native macOS Spaces (Mission
    /// Control). Consumers query `NativeSpaces` for details.
    case nativeSpaceChanged

    /// True when this event removes a window because its APP
    /// hid, rather than because the window went away (#913).
    ///
    /// A named predicate rather than an inline `if case` at the
    /// one site that asks: since #935 that site is
    /// `EventLoop.closeReturnRaiseStandsDown(after:)`, whose
    /// hide arm is behavior-tested (`OwnDialogFocusTests`) —
    /// and `HiddenAppRaiseTests` pins that only a hide reads as
    /// a hide drop.
    public var isHideDrop: Bool {
        if case .windowHidden = self { return true }
        return false
    }
}
