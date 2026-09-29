import AppKit

/// Front segment box background and frosted backdrop for SpaceBarOverlay.
extension SpaceBarOverlay {
    /// Lays out Boxed fill or per-box glass for the front chip.
    /// Mirrors `SpaceBarItemView`'s box — keep the two in step on
    /// any fill change; both boxes round through
    /// `SpaceBarItemView.boxRadius` (#1682).
    func layoutFrontBox(
        _ app: SpaceBarItemView.App,
        from start: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        style: SpaceBarLook
    ) {
        // Boxed fills the chip; per-box glass frosts it as a
        // backdrop; plain (shared plate) draws neither here.
        let boxed = style.hasBox
        let glass = wantsBoxGlass(style)
        guard boxed || glass else {
            frontBox.isHidden = true
            frontBorder.isHidden = true
            updateFrontGlass(nil, radius: 0, style: style)
            return
        }
        let pad = SpaceBarItemView.pad
        // Rounded ends pad the axis further (#1763).
        let endPad = chipEndPad(
            style,
            depth: depth,
            horizontal: horizontal
        )
        let content: NSView = app.glyph != nil ? frontGlyph : frontIcon
        let end =
            horizontal
            ? (frontName.isHidden
                ? content.frame.maxX : frontName.frame.maxX)
            : content.frame.maxY
        let length = max(end - start, cell) + endPad.total
        // The chip spans the strip like an item's box; padding
        // shrinks only the content in it (#1682).
        let cross = max(cell + pad * 2, depth)
        let crossOrigin = max((depth - cross) / 2, 0)
        let rect =
            horizontal
            ? CGRect(
                x: start - endPad.leading,
                y: crossOrigin,
                width: length,
                height: cross
            )
            : CGRect(
                x: crossOrigin,
                y: start - endPad.leading,
                width: cross,
                height: length
            )
        let radius = SpaceBarItemView.boxRadius(
            look: style,
            depth: depth,
            size: rect.size
        )
        frontBorder.frame = rect
        ShelfBorder.paint(
            frontBorder,
            shelf: style.shelf,
            surface: .box,
            cornerRadius: radius,
            sheen: style.sheen
        )
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
