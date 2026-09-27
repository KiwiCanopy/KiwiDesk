import AppKit

/// The painted sheen (#1644): a lighter top edge fading into the
/// colour, which holds to the bottom, on the focused ring,
/// the shelf's highlight and border, and the drag markers'
/// borders. Only HSL lightness moves — hue, saturation and alpha
/// stay the stroke's — so it is never real glass on a thin line
/// (owner 2026-09-26). The one ramp every surface and preview
/// draws, so none can drift.
public enum BorderSheen {
    /// How far a full-strength sheen moves the top: toward white,
    /// as a share of the headroom above the colour's lightness, or
    /// toward black, as a share of the lightness itself. A strength
    /// of 0.5 is the owner-eyeballed 0.45 lift (#1644).
    static let scale: CGFloat = 0.9
    /// Stop locations, top (0) to bottom (1).
    public static let locations: [CGFloat] = [0, 0.35, 1]
    /// The ramp's colours for `locations`, top to bottom, at the
    /// signed `strength` (clamped into `BorderStyle.sheenRange`);
    /// the plain colour throughout for a hex that does not parse.
    /// The FLAT band (every stop below the top) is the configured
    /// colour itself, which carries the ring's #578 contrast; the
    /// top may pass it either way, and the bottom never moves
    /// (owner 2026-09-27).
    public static func colors(
        hex: String,
        strength: CGFloat
    ) -> [NSColor] {
        let base = NSColor(kiwiHex: hex)
        guard let c = DragVisual.parseHex(hex) else {
            return Array(repeating: base, count: locations.count)
        }
        let (h, s, l) = BorderStyle.rgbToHSL(
            r: c.red,
            g: c.green,
            b: c.blue
        )
        let color = { (lightness: CGFloat) -> NSColor in
            let (r, g, b) = BorderStyle.hslToRGB(h: h, s: s, l: lightness)
            return NSColor(srgbRed: r, green: g, blue: b, alpha: c.alpha)
        }
        let amount = BorderStyle.clampSheen(strength) * scale
        let top =
            amount >= 0 ? l + (1 - l) * amount : l * (1 + amount)
        return [color(top), base, base]
    }

    /// The ramp as one `CGGradient`.
    static func gradient(
        hex: String,
        strength: CGFloat
    ) -> CGGradient? {
        CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors(hex: hex, strength: strength).map(\.cgColor)
                as CFArray,
            locations: locations
        )
    }

    /// Paints the ramp into `context` through `path`, stroked at
    /// `lineWidth` or filled when nil, top (`maxY`, the context
    /// being y-up) to bottom over `extent`.
    static func draw(
        _ path: CGPath,
        lineWidth: CGFloat?,
        extent: CGRect,
        hex: String,
        strength: CGFloat,
        in context: CGContext
    ) {
        guard let ramp = gradient(hex: hex, strength: strength) else {
            return
        }
        context.saveGState()
        context.addPath(path)
        if let lineWidth {
            context.setLineWidth(lineWidth)
            context.replacePathWithStrokedPath()
        }
        context.clip()
        context.drawLinearGradient(
            ramp,
            start: CGPoint(x: extent.midX, y: extent.maxY),
            end: CGPoint(x: extent.midX, y: extent.minY),
            options: []
        )
        context.restoreGState()
    }

    /// Fills `layer` with the ramp, top to bottom (unit space is
    /// y-up, `GlassTint.fade`'s convention).
    @MainActor
    static func paint(
        _ layer: CAGradientLayer,
        hex: String,
        strength: CGFloat
    ) {
        layer.colors = colors(hex: hex, strength: strength).map(\.cgColor)
        layer.locations = locations.map { NSNumber(value: $0) }
        layer.startPoint = CGPoint(x: 0.5, y: 1)
        layer.endPoint = CGPoint(x: 0.5, y: 0)
    }
}
