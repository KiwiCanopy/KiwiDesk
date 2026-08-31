import AppKit

/// Front segment box background and frosted backdrop for SpaceBarOverlay.
extension SpaceBarOverlay {
    /// Lays out Boxed fill or per-box glass for front application chip.
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
