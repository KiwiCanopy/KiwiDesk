import ApplicationServices
import CoreGraphics

/// Moves and resizes windows of other applications.
///
/// This is the safe fallback path via the public Accessibility
/// API. A SkyLight fast path (window-server-side transactions)
/// will be added on top later; the public surface stays the
/// same so callers never care which path executed.
@MainActor
public enum WindowControl {
    /// Applies a frame to a window element.
    ///
    /// Order matters: position first, then size — some apps
    /// clamp their size to the screen edge at the old origin.
    public static func setFrame(
        _ frame: CGRect,
        of element: AXUIElement
    ) {
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
