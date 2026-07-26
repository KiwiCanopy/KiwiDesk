import CoreGraphics
import Foundation

extension BorderStyle {
    /// The glow bloom's blur radius (pt) — and the amount the
    /// overlay frame grows on every side so the halo isn't
    /// clipped. Scaled with the (clamped) ring width so the
    /// bloom reads as a proportional aura at every width (#533,
    /// ui-designer verdict): a fixed blur swamps a hairline ring
    /// and vanishes against a thick one. `0.8` is the
    /// device-calibrated ratio (4 pt bloom on the default 5 pt
    /// ring); the floor keeps a hairline ring's halo present,
    /// the cap stops the overlay surface ballooning past
    /// diminishing visual returns. `BorderGeometryTests` pins
    /// the three calibration points. Derived, never stored —
    /// like `glowColor` below, it adds no profile-JSON key.
    public static func glowBlur(for width: CGFloat) -> CGFloat {
        min(12, max(2, 0.8 * width))
    }

    /// The glow bloom's color, derived from a ring color (#358).
    /// A bloom is a FILL, not a thin stroke, so it is freed from the
    /// stroke-legibility limit that keeps `focusedColor` deliberately
    /// dark — brighten it into a vivid halo. Hue is preserved (a blue
    /// ring blooms blue, never a muddy blue-green); saturation is
    /// floored and lightness lifted (the #358 designer formula:
    /// `s ← max(s, 0.80)`, `l ← clamp(l + 0.25, 0.55…0.72)`).
    /// Derived, never stored — it cannot drift from the ring color
    /// and adds no profile-JSON key. Parse failure returns the input.
    public static func glowColor(from hex: String) -> String {
        guard let c = DragVisual.parseHex(hex) else { return hex }
        var (h, s, l) = rgbToHSL(r: c.red, g: c.green, b: c.blue)
        // Floor saturation only for a color that HAS a hue — an
        // achromatic ring (grey/white/black, hue 0) must bloom grey,
        // not a spurious pink from flooring saturation onto hue-0.
        // (A white `focused_color` ships in the Monochrome palette.)
        if s > 0 { s = max(s, 0.80) }
        l = min(0.72, max(0.55, l + 0.25))
        let (r, g, b) = hslToRGB(h: h, s: s, l: l)
        return String(
            format: "#%02X%02X%02X",
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded())
        )
    }

    private static func rgbToHSL(
        r: CGFloat,
        g: CGFloat,
        b: CGFloat
    ) -> (CGFloat, CGFloat, CGFloat) {
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let l = (maxV + minV) / 2
        let d = maxV - minV
        guard d > 0 else { return (0, 0, l) }
        let s = d / (1 - abs(2 * l - 1))
        var h: CGFloat
        if maxV == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxV == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        return (h * 60, s, l)
    }

    private static func hslToRGB(
        h: CGFloat,
        s: CGFloat,
        l: CGFloat
    ) -> (CGFloat, CGFloat, CGFloat) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h / 60
        let rem = hp.truncatingRemainder(dividingBy: 2) - 1
        let x = c * (1 - abs(rem))
        let m = l - c / 2
        let base: (CGFloat, CGFloat, CGFloat)
        switch hp {
        case 0..<1: base = (c, x, 0)
        case 1..<2: base = (x, c, 0)
        case 2..<3: base = (0, c, x)
        case 3..<4: base = (0, x, c)
        case 4..<5: base = (x, 0, c)
        default: base = (c, 0, x)
        }
        return (base.0 + m, base.1 + m, base.2 + m)
    }
}
