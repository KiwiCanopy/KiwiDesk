import AppKit
import QuartzCore

/// The flip plate's faces (#1391): an untinted achromatic wash
/// with a hairline, the window's own corner radius and a
/// constant shadow, the app icon centred. No palette colour by
/// ruling — a Fill becomes a colour on glass only through
/// `GlassTint.apply` (#1297), and this is a `CALayer`.
enum MonocleFlipPlate {
    /// The wash per appearance: a white wash over a dark blurred
    /// ground reads as a grey slab, a black one as the Dock.
    static func wash(dark: Bool) -> CGColor {
        dark
            ? NSColor(white: 0, alpha: 0.40).cgColor
            : NSColor(white: 1, alpha: 0.55).cgColor
    }

    static func hairline(dark: Bool) -> CGColor {
        NSColor(white: dark ? 1 : 1, alpha: dark ? 0.18 : 0.35)
            .cgColor
    }

    /// The icon's side: 30 % of the plate's SHORTER side, capped,
    /// so a half-width vertical Monocle never pushes it past the
    /// plate.
    static func iconSide(for size: CGSize) -> CGFloat {
        min(0.30 * min(size.width, size.height), 256)
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
