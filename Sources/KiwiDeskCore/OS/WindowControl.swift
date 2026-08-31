import ApplicationServices
import CoreGraphics

/// Public Accessibility API window mover and resizer.
/// Deliberately NOT MainActor: AX set calls are blocking IPC
/// into the target app and thread-safe, so the animation
/// pipeline applies frames from a background queue.
public enum WindowControl {
    /// Applies frame via size → position → size: apps clamp
    /// whichever attribute is set first against the other's old
    /// value, so setting size on both sides of the move
    /// converges regardless of direction.
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
