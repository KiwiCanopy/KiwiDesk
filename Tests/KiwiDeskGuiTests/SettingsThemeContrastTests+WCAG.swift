import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// The WCAG arithmetic behind `SettingsThemeContrastTests`,
/// split from it at the §2.1 ceiling when #1198 added the accent
/// seal's two state fills.
///
/// It stays an extension rather than a shared helper: the
/// pairing list is the census and belongs in one file, while
/// these are the measurements that list is read through, and
/// nothing else measures them. `tests.md`'s bar for a shared
/// test primitive is a named way a divergent copy weakens a
/// guard — there is no second copy here to diverge.
extension SettingsThemeContrastTests {

    /// Contrast of the ink AS DRAWN — alpha-composited over the
    /// surface first when the render applies an opacity.
    func contrast(
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
    func resolved(
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

    func luminance(
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
