import AppKit

/// The shelf's one panel (#1517), which every bar draws in: a press
/// anywhere on it — an item, the plate, the divider's grip, an
/// overflow count — reaches `onPress` with the view it hits before
/// that view takes it. The one point a press in a bar closes the
/// hover peek (#1946), so no view re-spells it in its `mouseDown`.
final class ShelfPanel: NSPanel {
    var onPress: @MainActor (NSView?) -> Void = { _ in }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            onPress(contentView?.hitTest(event.locationInWindow))
        default:
            break
        }
        super.sendEvent(event)
    }
}
