import AppKit

/// Visual styling and layer color application for `AppBarItemView`.
extension AppBarItemView {
    /// Applies active and hover colors to text, icon, and
    /// background layers. The icon's dim is deliberately the full
    /// 0.4, NOT the Space Bar's 0.6 middle tier: a binary signal
    /// with no lower tier to collide with
    /// (`BarAccent.activeUnfocusedAlpha`). The group-count badge
    /// dims with the item's focus, as a Space Bar badge does,
    /// whatever the item draws — a glyph or title is tinted.
    func applyColors() {
        label.textColor = NSColor(kiwiHex: textColorHex)
        glyphLabel.textColor = NSColor(kiwiHex: textColorHex)
        let alpha: CGFloat = isActive || isHovered ? 1 : style.dimFactor
        iconView.alphaValue = alpha
        badge.alphaValue = alpha
        layer?.backgroundColor =
            NSColor(kiwiHex: boxColorHex).cgColor
        applyCornerRadius()
    }

    /// Cross dimension thickness for corner radius resolution.
    var crossThickness: CGFloat {
        horizontal ? bounds.height : bounds.width
    }

    /// Configures corner rounding and active mark clipping on item layers.
    func applyCornerRadius() {
        let radius = style.resolvedCornerRadius(
            forThickness: crossThickness
        )
        layer?.cornerRadius = radius
        layer?.maskedCorners = maskedCorners
        accentClip.frame = bounds
        accentClip.layer?.masksToBounds = true
        accentClip.layer?.cornerRadius = radius
        accentClip.layer?.maskedCorners = maskedCorners
        boxBorder.frame = bounds
        ShelfBorder.paint(
            boxBorder,
            shelf: style.shelf,
            surface: .box,
            under: drawnIndicator,
            cornerRadius: radius,
            sheen: style.sheen
        )
    }

    /// The corners this item rounds (`ItemCornerMask`, #1763).
    var maskedCorners: CACornerMask {
        ItemCornerMask.mask(
            shelf: style.shelf,
            first: isFirstInRun,
            last: isLastInRun,
            outlined: style.activeIndicator.drawsOutline,
            horizontal: horizontal
        )
    }

    /// An idle item's text takes the Space Bar's idle ink (#1938).
    var textColorHex: String {
        if isHovered { return style.hoverItemColor }
        return isActive
            ? style.activeItemColor
            : style.idleItemColor
    }

    /// Whether a box background should be painted
    /// (`PaletteSceneThumbnail`, #793).
    var hasBox: Bool {
        if isHovered { return true }
        return style.hasBox
    }

    // The Settings palette scene (`PaletteSceneThumbnail`, GUI
    // target) is a schematic twin of this box/accent logic —
    // keep the two in step when the box or accent rules change
    // (#793).
    var boxColorHex: String {
        if isHovered { return style.hoverFillColor }
        return style.hasBox ? style.fillColor : "#00000000"
    }

    /// The indicator this item draws, nil while inactive — read by
    /// the accent paint and layout, and the rim beneath it.
    var drawnIndicator: AppBarStyle.ActiveIndicator? {
        isActive ? style.activeIndicator : nil
    }

    /// Applies stroke or fill to active indicator layer (`layoutAccent`).
    func applyAccent() {
        layer?.borderWidth = 0
        let ink = BarAccent.flatInk(style.highlightColor, sheen: style.sheen)
        switch drawnIndicator {
        case nil:
            accent.isHidden = true
        case .outline?:
            accent.isHidden = false
            accent.layer?.borderWidth = style.resolvedHighlightWidth
            accent.layer?.borderColor = ink
            accent.layer?.backgroundColor =
                NSColor.clear.cgColor
        case .edgeMark?:
            accent.isHidden = false
            accent.layer?.borderWidth = 0
            accent.layer?.backgroundColor = ink
        }
        accent.paint = BarAccent.sheen(
            style.highlightColor,
            outline: drawnIndicator?.drawsOutline == true
                ? style.resolvedHighlightWidth : nil,
            strength: style.sheen,
            drawn: drawnIndicator != nil
        )
    }
}
