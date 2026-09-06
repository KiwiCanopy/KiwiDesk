import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// WCAG contrast over `SettingsTheme` tokens, resolved under one
/// appearance.
///
/// A **stateless primitive** — static functions, no assertions,
/// no state — shared by `SettingsThemeContrastTests` (which
/// measures the drawn pairing census) and
/// `KiwiProminentButtonStateTests` (which measures the accent
/// seal's three state fills). It was split out of the first at
/// the §2.1 ceiling when #1198 added the seal's two new fills,
/// and made shared rather than an extension when that same
/// change gave it a second consumer.
///
/// That is the `ColorVision` argument one family over, and it
/// is admitted on the same DIVERGENCE ground `tests.md` names:
/// both suites assert floors on the number this returns, so a
/// hand-copied linearisation that drifted would move a
/// threshold a guard rests on without failing anything. The
/// resolution path matters as much as the arithmetic — it is
/// the one the token suite pins, so all three suites measure
/// one truth.
enum ThemeContrast {

    /// Contrast of the ink AS DRAWN — alpha-composited over the
    /// surface first when the render applies an opacity.
    static func contrast(
        _ ink: Color,
        over surface: Color,
        wash: (color: Color, alpha: Double)? = nil,
        inkAlpha: Double,
        dark: Bool
    ) throws -> Double {
        let inkRGB = try resolved(ink, dark: dark)
        var surfaceRGB = try resolved(surface, dark: dark)
        // The wash lands first — the ink is drawn on the
        // composite, not on the bare token.
        if let wash {
            let washRGB = try resolved(wash.color, dark: dark)
            surfaceRGB = (
                r: wash.alpha * washRGB.r
                    + (1 - wash.alpha) * surfaceRGB.r,
                g: wash.alpha * washRGB.g
                    + (1 - wash.alpha) * surfaceRGB.g,
                b: wash.alpha * washRGB.b
                    + (1 - wash.alpha) * surfaceRGB.b
            )
        }
        let drawn = (
            r: inkAlpha * inkRGB.r
                + (1 - inkAlpha) * surfaceRGB.r,
            g: inkAlpha * inkRGB.g
                + (1 - inkAlpha) * surfaceRGB.g,
            b: inkAlpha * inkRGB.b
                + (1 - inkAlpha) * surfaceRGB.b
        )
        let la = luminance(drawn)
        let lb = luminance(surfaceRGB)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The token's sRGB components as resolved under one
    /// appearance — the same resolution path the token suite
    /// pins, so the two suites measure one truth.
    static func resolved(
        _ color: Color,
        dark: Bool
    ) throws -> (r: Double, g: Double, b: Double) {
        let appearance = try #require(
            NSAppearance(named: dark ? .darkAqua : .aqua)
        )
        var resolvedColor: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor =
                NSColor(color).usingColorSpace(.sRGB)
        }
        let srgb = try #require(resolvedColor)
        return (
            Double(srgb.redComponent),
            Double(srgb.greenComponent),
            Double(srgb.blueComponent)
        )
    }

    static func luminance(
        _ rgb: (r: Double, g: Double, b: Double)
    ) -> Double {
        func lin(_ v: Double) -> Double {
            v <= 0.04045
                ? v / 12.92
                : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(rgb.r) + 0.7152 * lin(rgb.g)
            + 0.0722 * lin(rgb.b)
    }
}
