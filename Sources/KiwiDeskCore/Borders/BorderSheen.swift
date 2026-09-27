import AppKit

/// The painted sheen (#1644): a lighter top edge fading into the
/// colour and a slight shade at the bottom, on the focused ring,
/// the shelf's highlight and border, and the drag markers'
/// borders. Only HSL lightness moves — hue, saturation and alpha
/// stay the stroke's — so it is never real glass on a thin line
/// (owner 2026-09-26). The one ramp every surface and preview
/// draws, so none can drift.
public enum BorderSheen {
    /// How far the top lifts toward white, as a share of the
    /// headroom above the colour's lightness (owner-eyeballed).
    static let lift: CGFloat = 0.45
    /// The bottom's lightness as a share of the colour's.
    static let shade: CGFloat = 0.8
    /// Stop locations, top (0) to bottom (1).
    public static let locations: [CGFloat] = [0, 0.35, 0.8, 1]
    /// The ramp's colours for `locations`, top to bottom; the plain
    /// colour throughout for a hex that does not parse. The FLAT
    /// band (the two middle stops) is the configured colour itself,
    /// which carries the ring's #578 contrast; the lifted top and
    /// the shaded bottom may pass it (owner 2026-09-27).
    public static func colors(hex: String) -> [NSColor] {
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
        return [color(l + (1 - l) * lift), base, base, color(l * shade)]
    }

    /// The ramp as one `CGGradient`.
    static func gradient(hex: String) -> CGGradient? {
        CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors(hex: hex).map(\.cgColor) as CFArray,
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
        in context: CGContext
    ) {
        guard let ramp = gradient(hex: hex) else { return }
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
    static func paint(_ layer: CAGradientLayer, hex: String) {
        layer.colors = colors(hex: hex).map(\.cgColor)
        layer.locations = locations.map { NSNumber(value: $0) }
        layer.startPoint = CGPoint(x: 0.5, y: 1)
        layer.endPoint = CGPoint(x: 0.5, y: 0)
    }
}
