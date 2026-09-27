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
    /// The #578 bar: a stroke clearing 3:1 on a ground keeps it at
    /// every stop of its ramp — the lift and the shade are capped
    /// where they would cross it. A colour already under the bar
    /// on a ground has no contrast there to lose.
    static let contrastFloor: CGFloat = 3
    /// What a capped stop aims at: the floor plus the drift an
    /// 8-bit colour and composited plate add once measured.
    static let capTarget: CGFloat = contrastFloor + 0.05
    /// The #578 grounds, as luminances: the wallpaper extremes a
    /// ring or a drag border sits on.
    public static let wallpapers: [CGFloat] = [1, 0]

    /// The grounds a bar surface sits on: the wallpaper extremes
    /// and its shelf Fill composited over each — the plate
    /// `IdleItemContrastTests` measures against.
    public static func grounds(plate fill: String) -> [CGFloat] {
        guard let c = DragVisual.parseHex(fill) else { return wallpapers }
        return wallpapers
            + wallpapers.map { wall in
                let ground = Double(wall)
                let mix = { (v: Double) in
                    v * c.alpha + ground * (1 - c.alpha)
                }
                return luminance((mix(c.red), mix(c.green), mix(c.blue)))
            }
    }

    /// The ramp's colours for `locations`, top to bottom, capped
    /// against `grounds`; the plain colour throughout for a hex
    /// that does not parse.
    public static func colors(
        hex: String,
        over grounds: [CGFloat] = wallpapers
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
        let rgb = { (lightness: CGFloat) in
            BorderStyle.hslToRGB(h: h, s: s, l: lightness)
        }
        let bound = grounds.filter {
            contrast(luminance(rgb(l)), $0) >= contrastFloor
        }
        let weakest = { (lightness: CGFloat) -> CGFloat in
            let y = luminance(rgb(lightness))
            return bound.map { contrast(y, $0) }.min() ?? .infinity
        }
        let color = { (lightness: CGFloat) -> NSColor in
            let (r, g, b) = rgb(lightness)
            return NSColor(srgbRed: r, green: g, blue: b, alpha: c.alpha)
        }
        let top = capped(from: l, to: l + (1 - l) * lift, weakest)
        let bottom = capped(from: l, to: l * shade, weakest)
        return [color(top), base, base, color(bottom)]
    }

    /// The lightness nearest `target`, walking from `start`, at
    /// which `weakest` stays at the floor.
    private static func capped(
        from start: CGFloat,
        to target: CGFloat,
        _ weakest: (CGFloat) -> CGFloat
    ) -> CGFloat {
        guard weakest(target) < capTarget else { return target }
        var (ok, bad) = (start, target)
        for _ in 0..<24 {
            let mid = (ok + bad) / 2
            if weakest(mid) >= capTarget { ok = mid } else { bad = mid }
        }
        return ok
    }

    /// WCAG relative luminance of an sRGB triple.
    static func luminance(_ rgb: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        let linear = { (v: CGFloat) -> CGFloat in
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1)
            + 0.0722 * linear(rgb.2)
    }

    /// WCAG contrast of two luminances.
    static func contrast(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The ramp as one `CGGradient`.
    static func gradient(
        hex: String,
        over grounds: [CGFloat] = wallpapers
    ) -> CGGradient? {
        CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors(hex: hex, over: grounds).map(\.cgColor)
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
        over grounds: [CGFloat] = wallpapers,
        in context: CGContext
    ) {
        guard let ramp = gradient(hex: hex, over: grounds) else { return }
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
