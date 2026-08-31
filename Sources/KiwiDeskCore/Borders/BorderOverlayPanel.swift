import AppKit

/// Border overlay NSPanel opting out of `constrainFrameRect`:
/// a plain NSPanel clamps frames below the menu bar, which
/// pins a top-row ring and swallows the dead-end rubber-band's
/// upward nudge whole (#436) — the ring is one rigid
/// translation, so a clamped top edge means zero visible
/// wiggle. A non-interactive overlay may sit anywhere, as the
/// unconstrained SkyLight fast path already does.
final class BorderOverlayPanel: NSPanel {
    override func constrainFrameRect(
        _ frameRect: NSRect,
        to screen: NSScreen?
    ) -> NSRect {
        frameRect
    }
}
