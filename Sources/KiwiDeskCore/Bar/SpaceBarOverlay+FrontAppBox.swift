import AppKit

/// Front segment box background and frosted backdrop for SpaceBarOverlay.
extension SpaceBarOverlay {
    /// Lays out the front chip's active indicator, then its Boxed
    /// fill or per-box glass. Mirrors `SpaceBarItemView`'s box —
    /// keep the two in step on any fill change; both boxes round
    /// through `SpaceBarItemView.boxRadius` (#1682).
    func layoutFrontBox(
        _ app: SpaceBarItemView.App,
        from start: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        style: SpaceBarLook
    ) {
        let (rect, radius) = frontChipRect(
            app,
            from: start,
            depth: depth,
            cell: cell,
            horizontal: horizontal,
            style: style
        )
        layoutFrontAccent(
            in: rect,
            radius: radius,
            style: style,
            horizontal: horizontal
        )
        // Boxed fills the chip; per-box glass frosts it as a
        // backdrop; plain (shared plate) draws neither here.
        let boxed = style.hasBox
        guard boxed || wantsBoxGlass(style) else {
            frontBox.isHidden = true
            frontBorder.isHidden = true
            updateFrontGlass(nil, radius: 0, style: style)
            return
        }
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

    /// The chip's frame and corner radius: its content from
    /// `start` to the title's (or glyph's) end, plus its end pads
    /// (#1763), spanning the strip like an item's box — padding
    /// shrinks only the content in it (#1682).
    private func frontChipRect(
        _ app: SpaceBarItemView.App,
        from start: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        style: SpaceBarLook
    ) -> (CGRect, CGFloat) {
        let pad = SpaceBarItemView.pad
        let endPad = Self.chipEndPad(style, depth: depth)
        let content: NSView = app.glyph != nil ? frontGlyph : frontIcon
        let end =
            horizontal
            ? (frontName.isHidden
                ? content.frame.maxX : frontName.frame.maxX)
            : content.frame.maxY
        let length = max(end - start, cell) + endPad.total
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
        return (rect, radius)
    }
}
