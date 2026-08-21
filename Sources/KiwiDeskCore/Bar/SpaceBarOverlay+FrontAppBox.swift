import AppKit

/// The front segment's chip chrome: the Boxed fill behind its
/// content and, under per-box glass, the frosted backdrop that
/// replaces it. Split from SpaceBarOverlay+FrontApp.swift, which
/// sat on the §2.1 file ceiling.
///
/// Content layout — the divider, the glyph and the window title —
/// stays in that file. What is here is only what sits BEHIND it,
/// which is why the split falls where it does: this half mirrors
/// `SpaceBarItemView`'s own box, and the two must stay in step on
/// any fill or corner change.
extension SpaceBarOverlay {
    /// A Boxed-only fill box behind the front-app content, so the
    /// segment reads as a chip like the Space items (Plain and
    /// Material draw their shared plate under it instead). Sits
    /// below the glyph/name, filled `fillColor`, rounded to match.
    /// Mirrors `SpaceBarItemView`'s box (fill + corner) — keep the
    /// two in step on any fill/corner change. The radius here
    /// resolves from cross-axis `depth`; the chip's from
    /// `min(width, height)` — they read alike but aren't identical.
    func layoutFrontBox(
        _ app: SpaceBarItemView.App,
        from start: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        style: SpaceBarStyle
    ) {
        // Boxed fills the chip; per-box glass frosts it as a
        // backdrop; plain (shared plate) draws neither here.
        let boxed = style.hasBox
        let glass = wantsBoxGlass(style)
        guard boxed || glass else {
            frontBox.isHidden = true
            updateFrontGlass(nil, radius: 0, style: style)
            return
        }
        let pad = SpaceBarItemView.pad
        let content: NSView = app.glyph != nil ? frontGlyph : frontIcon
        let end =
            horizontal
            ? (frontName.isHidden
                ? content.frame.maxX : frontName.frame.maxX)
            : content.frame.maxY
        let length = max(end - start, cell) + pad * 2
        let cross = cell + pad * 2
        let crossOrigin = max((depth - cross) / 2, 0)
        let rect =
            horizontal
            ? CGRect(
                x: start - pad,
                y: crossOrigin,
                width: length,
                height: cross
            )
            : CGRect(
                x: crossOrigin,
                y: start - pad,
                width: cross,
                height: length
            )
        let radius = style.resolvedCornerRadius(forThickness: depth)
        if boxed {
            frontBox.isHidden = false
            frontBox.wantsLayer = true
            frontBox.frame = rect
            frontBox.layer?.cornerRadius = radius
            frontBox.layer?.backgroundColor =
                NSColor(kiwiHex: style.fillColor).cgColor
            updateFrontGlass(nil, radius: 0, style: style)
        } else {
            frontBox.isHidden = true
            updateFrontGlass(rect, radius: radius, style: style)
        }
    }
}
