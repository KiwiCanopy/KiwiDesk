import AppKit

/// Border overlay NSPanel opting out of screen constraints (#436).
final class BorderOverlayPanel: NSPanel {
    override func constrainFrameRect(
        _ frameRect: NSRect,
        to screen: NSScreen?
    ) -> NSRect {
        frameRect
    }
}
