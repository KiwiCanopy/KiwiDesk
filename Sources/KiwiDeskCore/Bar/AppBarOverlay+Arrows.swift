import AppKit

/// Scroll arrows: end-of-strip zones shown only toward hidden
/// items, each click shifting the run by one slot. Split out of
/// AppBarOverlay to keep the render file under the size ceiling.
extension AppBarOverlay {
    /// Arrows sit at the strip's ends, shown only toward
    /// hidden items; clicking shifts the bar by one slot.
    func layoutArrows(
        strip: CGRect,
        m: Metrics,
        style: AppBarStyle
    ) {
        backArrow.isHidden =
            m.inset == 0 || scrollOffset <= 0.5
        forwardArrow.isHidden =
            m.inset == 0
            || m.total - m.viewport - scrollOffset <= 0.5
        let zone = Self.arrowZone
        backArrow.frame =
            m.horizontal
            ? CGRect(
                x: 0,
                y: 0,
                width: zone,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: 0,
                width: strip.width,
                height: zone
            )
        forwardArrow.frame =
            m.horizontal
            ? CGRect(
                x: strip.width - zone,
                y: 0,
                width: zone,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: strip.height - zone,
                width: strip.width,
                height: zone
            )
        // Under per-box glass the arrow's own fill goes transparent
        // so its frosted backdrop box shows through; the glyph and
        // its hover text color still read.
        let glass = wantsBoxGlass(style)
        let colors = BarArrowColors(
            text: NSColor(kiwiHex: style.itemColor),
            hoverText: NSColor(kiwiHex: style.hoverItemColor),
            box: glass ? .clear : NSColor(kiwiHex: style.fillColor),
            hover: glass
                ? .clear : NSColor(kiwiHex: style.hoverFillColor),
            cornerRoundness: style.cornerRoundness
        )
        backArrow.configure(
            glyph: m.horizontal ? "◂" : "▴",
            colors: colors
        )
        forwardArrow.configure(
            glyph: m.horizontal ? "▸" : "▾",
            colors: colors
        )
        if glass {
            updateArrowGlasses(style: style)
        }
        let step = m.slot + m.gap
        backArrow.onClick = { [weak self] in
            self?.scroll(by: -step)
        }
        forwardArrow.onClick = { [weak self] in
            self?.scroll(by: step)
        }
    }

    private func scroll(by delta: CGFloat) {
        scrollOffset += delta
        render(followingFocus: false)
    }
}
