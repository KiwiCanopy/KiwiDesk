import AppKit

/// The shelf's one panel (#1517), which every bar draws in: a press
/// anywhere on it — an item, the plate, the divider's grip, an
/// overflow count — reaches `onPress` with the view it hits before
/// that view takes it, and the press's type. The one point a press
/// in a bar closes the hover peek (#1946), so no view re-spells it
/// in its `mouseDown`.
final class ShelfPanel: NSPanel {
    var onPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }

    override func sendEvent(_ event: NSEvent) {
        if let type = Self.pressType(of: event) {
            onPress(contentView?.hitTest(event.locationInWindow), type)
        }
        super.sendEvent(event)
    }

    /// The press `event` is, as the peek reads it, nil for any
    /// other event — the one reading every panel that closes the
    /// peek takes (an overflow mark's too, #2235).
    static func pressType(of event: NSEvent) -> NSEvent.EventType? {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // A Control-click is AppKit's right-click (#761: its
            // menu opens on this panel).
            let controlClick =
                event.type == .leftMouseDown
                && event.modifierFlags.contains(.control)
            return controlClick ? .rightMouseDown : event.type
        default:
            return nil
        }
    }
}
