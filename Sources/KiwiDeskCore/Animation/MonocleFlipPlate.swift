import AppKit
import QuartzCore

/// The flip plate (#1391): an untinted achromatic wash with a
/// hairline, each window's own corner radius and a constant
/// shadow, the app icon centred — no palette colour, no text
/// (the design entry has the ruling).
enum MonocleFlipPlate {
    /// The wash per appearance: a white wash over a dark blurred
    /// ground reads as a grey slab, a black one as the Dock.
    static func wash(dark: Bool) -> CGColor {
        dark
            ? NSColor(white: 0, alpha: 0.40).cgColor
            : NSColor(white: 1, alpha: 0.55).cgColor
    }

    static func hairline(dark: Bool) -> CGColor {
        NSColor(white: 1, alpha: dark ? 0.18 : 0.35).cgColor
    }

    /// The icon's side: 30 % of the plate's SHORTER side, capped,
    /// so a half-width vertical Monocle never pushes it past the
    /// plate.
    static func iconSide(for size: CGSize) -> CGFloat {
        min(0.30 * min(size.width, size.height), 256)
    }

    /// The card: both faces centred on the outgoing frame — the
    /// incoming one lands on its own issued size, which shares
    /// that centre (#677) — turning about the plan's axis with
    /// the plan's sign, the turn beginning after the blur-in so
    /// the midpoint is edge-on. Perspective scales with the
    /// extent that rotates, or a window-sized plate's edges fly
    /// off screen.
    static func card(
        _ plan: MonocleFlipPlan,
        from: MonocleFlipOverlay.Face,
        to: MonocleFlipOverlay.Face,
        fromRect: CGRect,
        toRect: CGRect,
        cornerRadii: (from: CGFloat, to: CGFloat),
        dark: Bool,
        scale: CGFloat,
        reduceMotion: Bool
    ) -> CALayer {
        let card = CALayer()
        card.frame = fromRect
        var perspective = CATransform3DIdentity
        let extent =
            plan.axis == .vertical ? fromRect.width : fromRect.height
        perspective.m34 = -1 / max(extent * 2, 700)
        card.sublayerTransform = perspective
        let centre = CGPoint(
            x: fromRect.width / 2,
            y: fromRect.height / 2
        )
        let front = face(
            icon: from.icon,
            size: fromRect.size,
            cornerRadius: cornerRadii.from,
            dark: dark,
            scale: scale
        )
        let back = face(
            icon: to.icon,
            size: toRect.size,
            cornerRadius: cornerRadii.to,
            dark: dark,
            scale: scale
        )
        front.position = centre
        back.position = centre
        let sign = Double(plan.sign)
        back.transform = rotation(axis: plan.axis, radians: -sign * .pi)
        let axis = plan.axis == .vertical ? "y" : "x"
        front.add(
            BarMotion.flipTurn(
                axis: axis,
                from: 0,
                to: sign * .pi,
                duration: plan.duration,
                delay: MonocleFlipPlan.fadeIn,
                reduceMotion: reduceMotion
            ),
            forKey: "turn"
        )
        back.add(
            BarMotion.flipTurn(
                axis: axis,
                from: -sign * .pi,
                to: 0,
                duration: plan.duration,
                delay: MonocleFlipPlan.fadeIn,
                reduceMotion: reduceMotion
            ),
            forKey: "turn"
        )
        card.addSublayer(front)
        card.addSublayer(back)
        return card
    }

    /// One face: a plate of `size` anchored at its centre,
    /// single-sided so the turn hides it past edge-on.
    static func face(
        icon: NSImage?,
        size: CGSize,
        cornerRadius: CGFloat,
        dark: Bool,
        scale: CGFloat
    ) -> CALayer {
        let plate = CALayer()
        plate.bounds = CGRect(origin: .zero, size: size)
        plate.contentsScale = scale
        plate.cornerRadius = cornerRadius
        plate.backgroundColor = wash(dark: dark)
        plate.borderColor = hairline(dark: dark)
        plate.borderWidth = 1
        plate.shadowColor = NSColor.black.cgColor
        plate.shadowOpacity = 0.45
        plate.shadowRadius = 18
        plate.shadowOffset = CGSize(width: 0, height: -6)
        plate.isDoubleSided = false
        plate.allowsEdgeAntialiasing = true
        let side = iconSide(for: size)
        let glyph = CALayer()
        glyph.frame = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )
        glyph.contentsScale = scale
        glyph.contents = rasterised(icon, side: side, scale: scale)
        glyph.contentsGravity = .resizeAspect
        plate.addSublayer(glyph)
        return plate
    }

    /// The icon at the layer's PIXEL size, or the 1× rep is
    /// picked and the icon blurs on Retina.
    private static func rasterised(
        _ icon: NSImage?,
        side: CGFloat,
        scale: CGFloat
    ) -> CGImage? {
        guard let icon else { return nil }
        var proposed = CGRect(
            origin: .zero,
            size: CGSize(width: side * scale, height: side * scale)
        )
        return icon.cgImage(
            forProposedRect: &proposed,
            context: nil,
            hints: [.ctm: AffineTransform(scale: scale)]
        )
    }

    /// A rotation about the plan's axis.
    static func rotation(
        axis: MonocleFlipPlan.Axis,
        radians: Double
    ) -> CATransform3D {
        switch axis {
        case .vertical:
            return CATransform3DMakeRotation(radians, 0, 1, 0)
        case .horizontal:
            return CATransform3DMakeRotation(radians, 1, 0, 0)
        }
    }
}
