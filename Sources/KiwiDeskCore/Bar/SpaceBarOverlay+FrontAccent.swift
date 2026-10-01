import AppKit

/// The front-app chip's active indicator (#1856): the Space Bar's
/// own outline or edge mark, at the shelf's highlight width, in
/// the front app's `resolvedFocusedHighlightColor` — the chip IS
/// the focused window, so it is always drawn.
extension SpaceBarOverlay {
    /// Lays the indicator over the chip at `rect`, clipped to its
    /// `radius` like a Space item's (`SpaceBarItemView` ▸
    /// `layoutAccent`), over the chip's border.
    func layoutFrontAccent(
        in rect: CGRect,
        radius: CGFloat,
        style: SpaceBarLook
    ) {
        frontAccentClip.isHidden = false
        frontAccentClip.frame = rect
        frontAccentClip.layer?.masksToBounds = true
        frontAccentClip.layer?.cornerRadius = radius
        let hex = style.resolvedFocusedHighlightColor
        let outline = style.activeIndicator == .outline
        let bounds = frontAccentClip.bounds
        frontAccent.paint = BarAccent.sheen(
            hex,
            outline: outline ? style.resolvedHighlightWidth : nil,
            strength: style.sheen,
            drawn: true
        )
        let ink = BarAccent.flatInk(hex, sheen: style.sheen)
        guard let layer = frontAccent.layer else { return }
        if outline {
            let inset = style.hasBox ? 0 : BarAccent.capsuleInset
            frontAccent.frame = bounds.insetBy(dx: inset, dy: inset)
            layer.backgroundColor = nil
            layer.borderColor = ink
            layer.borderWidth = style.resolvedHighlightWidth
            layer.cornerRadius = max(0, radius - inset)
        } else {
            frontAccent.frame = BarAccent.edgeMarkFrame(
                in: bounds,
                edge: style.edge,
                thickness: style.edgeMarkThickness
            )
            layer.borderWidth = 0
            layer.cornerRadius = 0
            layer.backgroundColor = ink
        }
    }

}
