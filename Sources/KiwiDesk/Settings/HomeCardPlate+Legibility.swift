import KiwiDeskCore
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
        guard
            let c = HexColor.parse(
                hex.trimmingCharacters(in: .whitespaces)
            )
        else { return false }
        let lum =
            0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
        let effective =
            c.alpha * lum + (1 - c.alpha) * plateLuminance
        return abs(effective - plateLuminance) >= 0.15
    }
}
