import Foundation

/// Colour-vision maths: the protanopia transform, WCAG contrast,
/// and the separation measures the colour-vision guards assert on
/// (#511). The numbers are the argument the palette rulings rest
/// on (`docs/design-decisions.md`), so this is the one place that
/// computes them: a guard, a derived ink or a Settings warning
/// measuring a colour reads it here, never a copy, since a drifted
/// copy moves the number a guard asserts on without failing
/// anything. Pure and actor-free; the steps inside the measures
/// and the guards' hue sweep stay internal.
public enum ColorVision {
    /// The separation floor every CVD guard measures
    /// against — a suite asserting on this quantity reads it
    /// here rather than restating the number.
    ///
    /// One number on purpose, and the structural reason comes
    /// first: **the two families share hexes.** The drop-zone
    /// amber *is* `SpaceBarStyle.focusedItemColor`, and most
    /// palettes tie target to the focused accent — so
    /// one hex is routinely measured in both families at once.
    /// Two thresholds over one colour is a latent contradiction:
    /// a retune could clear the drag floor and fail the accent
    /// floor on the identical value, and whichever guard ran
    /// first would decide. Secondarily, motion is a redundant cue
    /// the drag overlay has and the Space Bar does not, so a
    /// *lower* drag floor sounds arguable — but the two overlays
    /// are frequently adjacent, the reader resolves
    /// which-is-which from a near-static glance, and the drag
    /// family has *less* headroom anyway (see below), so it would
    /// have been backwards.
    ///
    /// **A floor, not a target.** What actually ships: the drag
    /// default at **76** is the lowest pair in either family, the
    /// Space Bar default at **93** the lowest of its own, and
    /// every authored palette sits at **119 or above**. 60 is
    /// comfortably past the 22 of the pre-#470 default and past
    /// both near-miss retunes considered at the time (`#F0B858`
    /// 23, `#E09B2E` 39), while leaving room to retune a hex
    /// without tripping a guard on a colour that is actually
    /// fine. A new palette landing at 61 passes while being far
    /// worse than anything shipped — aim for the band, and let
    /// this catch the disasters.
    ///
    /// If an eye-confirm asks for a colour that trips this:
    /// re-measure, and move the floor only if the new
    /// *measurement* justifies it. Lowering it to fit a pick
    /// discards the argument the number encodes.
    public static let separationFloor: Double = 60

    /// sRGB → linear, the same transfer function WCAG uses.
    static func linear(_ value: Double) -> Double {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    static func components(_ hex: String) -> (
        r: Double, g: Double, b: Double
    )? {
        guard let rgb = HexColor.parse(hex) else { return nil }
        // `HexColor.parse` already normalizes each channel to 0...1.
        return (rgb.red, rgb.green, rgb.blue)
    }

    /// Relative luminance, WCAG's definition.
    public static func luminance(_ hex: String) -> Double? {
        guard let c = components(hex) else { return nil }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g)
            + 0.0722 * linear(c.b)
    }

    /// Rec. 709 luma over the ENCODED channels, 0...1, alpha
    /// ignored: the Settings plates' legibility measure (#786,
    /// #2859), not WCAG's linear `luminance`.
    public static func luma(_ hex: String) -> Double? {
        guard let c = components(hex) else { return nil }
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    /// How far `top`, laid at its own alpha over the opaque
    /// `ground`, sits from `ground` in `luma` — in either
    /// direction, so a near-ground colour and a translucent
    /// wisp both measure small.
    public static func lumaDistance(
        _ top: String,
        over ground: String
    ) -> Double? {
        guard let c = HexColor.parse(top), let floor = luma(ground)
        else { return nil }
        let lum = 0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
        let effective = c.alpha * lum + (1 - c.alpha) * floor
        return abs(effective - floor)
    }

    /// WCAG contrast ratio, 1...21.
    public static func contrast(
        _ a: String,
        _ b: String
    ) -> Double? {
        guard let x = luminance(a), let y = luminance(b) else {
            return nil
        }
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// Simulates protanopia (Viénot/Brettel LMS reduction) and
    /// returns the result in 0...255 sRGB.
    ///
    /// Protan is the strictest of the three for this palette:
    /// it is the axis a green primary and a warm focused accent
    /// collapse onto, so it is the one the rules are written
    /// against. Deutan tracks it closely; tritan is unaffected.
    static func protanope(_ hex: String) -> (
        r: Double, g: Double, b: Double
    )? {
        guard let c = components(hex) else { return nil }
        let r = linear(c.r)
        let g = linear(c.g)
        let b = linear(c.b)
        // sRGB → LMS. Only M and S are needed: the
        // long-wavelength cone is the missing one, so L is
        // discarded and reconstructed from the other two.
        let m = 3.45565 * r + 27.1554 * g + 3.86714 * b
        let s = 0.0299566 * r + 0.184309 * g + 1.46709 * b
        let lp = 2.02344 * m - 2.52581 * s
        // LMS → sRGB.
        func encode(_ value: Double) -> Double {
            let v = min(max(value, 0), 1)
            let s =
                v <= 0.0031308
                ? 12.92 * v
                : 1.055 * pow(v, 1 / 2.4) - 0.055
            return min(max(s, 0), 1) * 255
        }
        return (
            encode(
                0.0809444479 * lp - 0.130504409 * m
                    + 0.116721066 * s
            ),
            encode(
                -0.0102485335 * lp + 0.0540193266 * m
                    - 0.113614708 * s
            ),
            encode(
                -0.000365296938 * lp - 0.00412161469 * m
                    + 0.693511405 * s
            )
        )
    }

    /// HSL → hex, for sweeping a hue family in a guard.
    static func hex(
        hue: Double,
        saturation: Double,
        lightness: Double
    ) -> String {
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let hp = hue.truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double) =
            switch hp {
            case ..<1: (c, x, 0)
            case ..<2: (x, c, 0)
            case ..<3: (0, c, x)
            case ..<4: (0, x, c)
            case ..<5: (x, 0, c)
            default: (c, 0, x)
            }
        let m = lightness - c / 2
        let bytes = [r1, g1, b1].map {
            Int((($0 + m) * 255).rounded())
        }
        return "#"
            + bytes.map { String(format: "%02X", $0) }
            .joined()
    }

    /// A translucent `top` laid over an opaque `bottom`, returned
    /// as an opaque hex — what a bar's fill actually looks like
    /// once a wallpaper shows through it.
    ///
    /// Mixed on the sRGB **bytes**, not in linear light, because
    /// that is what the window server puts on screen: the plate a
    /// reader sees is the encoded blend, and measuring a
    /// physically-correct blend nobody renders would gate the
    /// palettes on the wrong colour. Nil for either operand
    /// unparseable, and an alpha on `bottom` is ignored — a
    /// wallpaper is opaque.
    public static func composite(
        _ top: String,
        over bottom: String
    ) -> String? {
        guard let over = HexColor.parse(top),
            let under = components(bottom)
        else { return nil }
        let a = over.alpha
        let mix = [
            (over.red, under.r), (over.green, under.g),
            (over.blue, under.b),
        ]
        .map { Int((($0.0 * a + $0.1 * (1 - a)) * 255).rounded()) }
        return "#"
            + mix.map { String(format: "%02X", $0) }.joined()
    }

    /// Euclidean distance in simulated sRGB, 0...441 (√3·255).
    public static func separation(
        _ a: String,
        _ b: String
    ) -> Double? {
        guard let x = protanope(a), let y = protanope(b) else {
            return nil
        }
        let dr = x.r - y.r
        let dg = x.g - y.g
        let db = x.b - y.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}
