import Foundation

@testable import KiwiDeskCore

/// Colour-vision maths shared by the CVD separation guards.
///
/// A **stateless primitive**: no assertions, no setup/teardown, no
/// suite of its own. It is the fourth ratified exception to the
/// per-file-private-helper convention (AGENTS.md §5), extracted at
/// the *second* copy on drift risk alone — the same argument that
/// pulled `SourceScan.swift` out. Two suites now measure the same
/// quantity (`SpaceBarAccentSeparationTests` for the Space Bar's
/// active/focused pair, `DragPairSeparationTests` for the drag
/// overlay's origin/target pair), and a hand-copied transform that
/// drifted in one of them would silently move the number a guard
/// is asserting on — a guard passing for the wrong reason, which
/// is precisely what these guards exist to prevent. The numbers
/// are the argument here (see `docs/design-decisions.md`), so
/// there must be exactly one place that computes them.
enum ColorVision {
    /// sRGB → linear, the same transfer function WCAG uses.
    static func linear(_ value: Double) -> Double {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    static func components(_ hex: String) -> (
        r: Double, g: Double, b: Double
    )? {
        guard let rgb = DragVisual.parseHex(hex) else { return nil }
        // `parseHex` already normalizes each channel to 0...1.
        return (rgb.red, rgb.green, rgb.blue)
    }

    /// Relative luminance, WCAG's definition.
    static func luminance(_ hex: String) -> Double? {
        guard let c = components(hex) else { return nil }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g)
            + 0.0722 * linear(c.b)
    }

    /// WCAG contrast ratio, 1...21.
    static func contrast(_ a: String, _ b: String) -> Double? {
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

    /// Euclidean distance in simulated sRGB, 0...441 (√3·255).
    static func separation(_ a: String, _ b: String) -> Double? {
        guard let x = protanope(a), let y = protanope(b) else {
            return nil
        }
        let dr = x.r - y.r
        let dg = x.g - y.g
        let db = x.b - y.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}
