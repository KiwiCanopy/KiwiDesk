import ApplicationServices
import CoreGraphics

/// Moves and resizes windows of other applications.
///
/// This is the safe fallback path via the public Accessibility
/// API. A SkyLight fast path (window-server-side transactions)
/// will be added on top later; the public surface stays the
/// same so callers never care which path executed.
///
/// Deliberately NOT MainActor: AX set calls are blocking IPC
/// into the target app and are thread-safe, so the animation
/// pipeline applies frames from a background queue.
public enum WindowControl {
    /// Applies a frame to a window element.
    ///
    /// Size → position → size: apps clamp whichever attribute
    /// is set first against the other's old value, so setting
    /// size on both sides of the move converges regardless of
    /// direction.
    public static func setFrame(
        _ frame: CGRect,
        of element: AXUIElement
    ) {
        setSize(frame.size, of: element)
        setPosition(frame.origin, of: element)
        setSize(frame.size, of: element)
    }

    public static func setPosition(
        _ position: CGPoint,
        of element: AXUIElement
    ) {
        var point = position
        guard let value = AXValueCreate(.cgPoint, &point) else {
            return
        }
        AXUIElementSetAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            value
        )
    }

    public static func setSize(
        _ size: CGSize,
        of element: AXUIElement
    ) {
        var box = size
        guard let value = AXValueCreate(.cgSize, &box) else {
            return
        }
        AXUIElementSetAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            value
        )
    }
}
