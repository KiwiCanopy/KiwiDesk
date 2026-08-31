import ApplicationServices
import CoreGraphics

/// Public Accessibility API window mover and resizer.
public enum WindowControl {
    /// Applies frame to AXUIElement via size-position-size sequence.
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
