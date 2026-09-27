import AppKit

/// The painted sheen on a coloured stroke (#1644 prototype): a
/// lighter top edge fading into the colour, and a slight shade at
/// the bottom. Only lightness moves — hue, saturation and alpha
/// stay the stroke's — so it is never real glass on a 2 pt line
/// (owner 2026-09-26). One ramp for the focus ring and the bar
/// highlight, so the two surfaces cannot drift.
enum BorderSheen {
    /// How far the top lifts toward white, as a share of the
    /// headroom above the colour's lightness.
    static let lift: CGFloat = 0.45
    /// The bottom's lightness as a share of the colour's.
    static let shade: CGFloat = 0.8
    /// Stop locations, top (0) to bottom (1).
    static let locations: [CGFloat] = [0, 0.35, 0.8, 1]

    /// The ramp's colours for `locations`, top to bottom; the
    /// plain colour four times for a hex that does not parse.
    static func colors(hex: String) -> [NSColor] {
        let base = NSColor(kiwiHex: hex)
        guard let c = DragVisual.parseHex(hex) else {
            return Array(repeating: base, count: 4)
        }
        let (h, s, l) = BorderStyle.rgbToHSL(
            r: c.red,
            g: c.green,
            b: c.blue
        )
        let color = { (lightness: CGFloat) -> NSColor in
            let (r, g, b) = BorderStyle.hslToRGB(
                h: h,
                s: s,
                l: min(1, max(0, lightness))
            )
            return NSColor(
                srgbRed: r,
                green: g,
                blue: b,
                alpha: c.alpha
            )
        }
        return [
            color(l + (1 - l) * lift), base, base, color(l * shade),
        ]
    }

    /// The ramp as one `CGGradient` for a context stroke.
    static func gradient(hex: String) -> CGGradient? {
        CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors(hex: hex).map(\.cgColor) as CFArray,
            locations: locations
        )
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
