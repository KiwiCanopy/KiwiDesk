import SwiftUI

/// Palette fold legibility floor calculations (`HomeCardChromeTests`, #786).
extension HomeCardPlate {
    /// Plate weighted luminance arithmetic baseline.
    static let plateLuminance =
        0.2126 * (0x12 / 255.0)
        + 0.7152 * (0x25 / 255.0)
        + 0.0722 * (0x1A / 255.0)

    /// Whether a user hex can be seen on the plate at all: its
    /// alpha-composited luminance must sit a floor's width from
    /// the plate's own, in EITHER direction — a near-plate dark
    /// and a translucent wisp both fail.
    static func plateLegible(_ hex: String) -> Bool {
        guard let c = rgba(hex) else { return false }
        let lum =
            0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        let effective =
            c.a * lum + (1 - c.a) * plateLuminance
        return abs(effective - plateLuminance) >= 0.15
    }

    private static func rgba(
        _ hex: String
    ) -> (r: Double, g: Double, b: Double, a: Double)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
            let v = UInt64(s, radix: 16)
        else { return nil }
        if s.count == 6 {
            return (
                Double((v >> 16) & 0xFF) / 255,
                Double((v >> 8) & 0xFF) / 255,
                Double(v & 0xFF) / 255,
                1
            )
        }
        return (
            Double((v >> 24) & 0xFF) / 255,
            Double((v >> 16) & 0xFF) / 255,
            Double((v >> 8) & 0xFF) / 255,
            Double(v & 0xFF) / 255
        )
    }
}
