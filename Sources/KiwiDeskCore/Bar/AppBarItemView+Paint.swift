import AppKit

/// Visual styling and layer color application for `AppBarItemView`.
extension AppBarItemView {
    /// Applies active and hover colors to text, icon, and
    /// background layers. The icon's dim is deliberately the full
    /// 0.4, NOT the Space Bar's 0.6 middle tier: a binary signal
    /// with no lower tier to collide with
    /// (`BarAccent.activeUnfocusedAlpha`).
    func applyColors() {
        label.textColor = NSColor(kiwiHex: textColorHex)
        glyphLabel.textColor = NSColor(kiwiHex: textColorHex)
        iconView.alphaValue =
            isActive || isHovered
            ? 1 : style.dimFactor
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
        accentClip.frame = bounds
        accentClip.layer?.masksToBounds = true
        accentClip.layer?.cornerRadius = radius
        accentClip.layer?.maskedCorners = maskedCorners
    }

    /// Masked corners for item background rounding.
    var maskedCorners: CACornerMask {
        let all: CACornerMask = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
        ]
        if style.hasBox { return all }
        let leading: CACornerMask =
            horizontal
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let trailing: CACornerMask =
            horizontal
            ? [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            : [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        var corners: CACornerMask = []
        if isFirstInRun { corners.formUnion(leading) }
        if isLastInRun { corners.formUnion(trailing) }
        return corners
    }

    var textColorHex: String {
        if isHovered { return style.hoverItemColor }
        return isActive
            ? style.activeItemColor
            : style.itemColor
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

    /// Active item indicator appearance mode.
    enum AccentMode { case none, outline, edgeMark }

    var accentMode: AccentMode {
        guard isActive, style.activeIndicator != .gap else {
            return .none
        }
        return style.activeIndicator == .outline
            ? .outline : .edgeMark
    }

    /// Applies stroke or fill to active indicator layer (`layoutAccent`).
    func applyAccent() {
        layer?.borderWidth = 0
        switch accentMode {
        case .none:
            accent.isHidden = true
        case .outline:
            accent.isHidden = false
            accent.layer?.borderWidth = 2
            accent.layer?.borderColor =
                NSColor(kiwiHex: style.highlightColor).cgColor
            accent.layer?.backgroundColor =
                NSColor.clear.cgColor
        case .edgeMark:
            accent.isHidden = false
            accent.layer?.borderWidth = 0
            accent.layer?.backgroundColor =
                NSColor(kiwiHex: style.highlightColor).cgColor
        }
    }
}
