import AppKit

/// The focus-ring overlay's window. A plain `NSPanel` clamps every
/// frame it is given so the title bar stays below the menu bar
/// (`constrainFrameRect`). That pins a top-row ring in place and
/// swallows the dead-end rubber-band's upward nudge (#436): the whole
/// ring is one rigid translation, so a clamped top edge means the
/// bottom and sides never move either — zero visible wiggle, unlike
/// the unclamped left/right/down bumps.
///
/// This subclass opts out. The ring is a non-interactive auxiliary
/// overlay positioned to the pixel and never dragged, so it may sit
/// anywhere — including lapping under the menu bar, exactly as the
/// SkyLight fast path (which is unconstrained) already does.
final class BorderOverlayPanel: NSPanel {
    override func constrainFrameRect(
        _ frameRect: NSRect,
        to screen: NSScreen?
    ) -> NSRect {
        frameRect
    }
}
