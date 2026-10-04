import AppKit

/// The ring's glow and sheen layers, rebuilt on every render.
extension AppKitBorderOverlay {
    /// Renders outer glow halo from filled silhouette (#358, #533).
    func applyGlow(
        geometry: BorderGeometry,
        rect: CGRect,
        colorHex: String
    ) {
        guard geometry.glowMargin > 0 else {
            shape.shadowOpacity = 0
            shape.shadowColor = nil
            shape.shadowPath = nil
            glowBoost.shadowOpacity = 0
            glowBoost.shadowColor = nil
            glowBoost.shadowPath = nil
            shape.mask = nil
            glowBoost.mask = nil
            return
        }
        let half = geometry.lineWidth / 2
        let radius = geometry.cornerRadius
        let outerRadius = radius <= 0 ? 0 : radius + half
        let silhouette = CGPath(
            roundedRect: rect.insetBy(dx: -half, dy: -half),
            cornerWidth: outerRadius,
            cornerHeight: outerRadius,
            transform: nil
        )
        let glow = NSColor.kiwiGlow(hex: colorHex)
        shape.shadowColor = glow
        shape.shadowRadius = geometry.glowMargin
        shape.shadowOpacity = 1
        shape.shadowOffset = .zero
        shape.shadowPath = silhouette
        glowBoost.frame = shape.frame
        glowBoost.shadowColor = glow
        glowBoost.shadowRadius = geometry.glowMargin / 2
        glowBoost.shadowOpacity = 1
        glowBoost.shadowOffset = .zero
        glowBoost.shadowPath = silhouette
        let inner = rect.insetBy(dx: half, dy: half)
        let innerRadius = max(0, radius - half)
        let cutout = CGMutablePath()
        cutout.addRect(shape.bounds)
        if inner.width > 0, inner.height > 0 {
            cutout.addRoundedRect(
                in: inner,
                cornerWidth: min(innerRadius, inner.width / 2),
                cornerHeight: min(innerRadius, inner.height / 2)
            )
        }
        for (layer, mask) in [
            (shape, shapeGlowMask), (glowBoost, boostGlowMask),
        ] {
            mask.frame = layer.bounds
            mask.path = cutout
            mask.fillRule = .evenOdd
            layer.mask = mask
        }
    }

    /// Paints the sheen ramp over the stroke's own extent (#1644).
    func applySheen(
        geometry: BorderGeometry,
        rect: CGRect,
        colorHex: String
    ) {
        sheen.isHidden = geometry.sheen == 0
        guard geometry.sheen != 0 else { return }
        let half = geometry.lineWidth / 2
        sheen.frame = rect.insetBy(dx: -half, dy: -half)
        sheen.contentsScale = shape.contentsScale
        sheenMask.frame = sheen.bounds
        sheenMask.path = CGPath(
            roundedRect: rect.offsetBy(
                dx: half - rect.minX,
                dy: half - rect.minY
            ),
            cornerWidth: geometry.cornerRadius,
            cornerHeight: geometry.cornerRadius,
            transform: nil
        )
        sheenMask.lineWidth = geometry.lineWidth
        sheenMask.strokeColor = NSColor.black.cgColor
        sheenMask.fillColor = nil
        sheenMask.contentsScale = shape.contentsScale
        sheen.mask = sheenMask
        BorderSheen.paint(
            sheen,
            hex: colorHex,
            strength: geometry.sheen
        )
    }
}
