import Foundation
import KiwiDeskCore

/// The plates' legibility floor and the light plate's verdict
/// (`HomeCardPaletteWiringTests`, `PlateGroundTests`; #786,
/// #2859). The grounds' hexes are their tokens'
/// (`previewPlate`, `lightPlate`, `lightOutline`), pinned equal
/// by those suites.
extension HomeCardPlate {
    static let darkGround = "#12251A"
    static let lightGround = "#DFE6DC"
    static let lightOutline = "#BCC5BA"

    /// The luma distance a colour must keep from its ground.
    static let legibilityFloor = 0.15

    /// A ground's luma, the floor's baseline.
    static func plateLuminance(_ ground: String) -> Double {
        ColorVision.luma(ground) ?? 0
    }

    /// Whether a user hex can be seen on `ground` at all: its
    /// alpha-composited luma must sit a floor's width from the
    /// ground's own, in EITHER direction — a near-ground colour
    /// and a translucent wisp both fail.
    static func plateLegible(_ hex: String, on ground: String) -> Bool {
        guard
            let distance = ColorVision.lumaDistance(
                hex.trimmingCharacters(in: .whitespaces),
                over: ground
            )
        else { return false }
        return distance >= legibilityFloor
    }

    /// The colour that marks focus on the plate: the ring, or the
    /// active item colour while borders are off and no ring draws.
    static func focusHex(_ settings: TilingSettings) -> String {
        settings.borderStyle.enabled
            ? settings.borderStyle.focusedColor
            : settings.kiwishelf.activeItemColor
    }

    /// Whether a ring reads on the light plate (#2859 ruling 1):
    /// it clears the floor, out-contrasts the unfocused outline and
    /// separates from it under protan simulation.
    static func holdsLightRing(_ hex: String) -> Bool {
        let ring = hex.trimmingCharacters(in: .whitespaces)
        guard
            let drawn = ColorVision.composite(ring, over: lightGround),
            let ringContrast = ColorVision.contrast(drawn, lightGround),
            let outlineContrast = ColorVision.contrast(
                lightOutline,
                lightGround
            ),
            let separation = ColorVision.separation(drawn, lightOutline)
        else { return false }
        return plateLegible(ring, on: lightGround)
            && ringContrast > outlineContrast
            && separation >= ColorVision.separationFloor
    }

    /// The ring a picture draws on the light plate: the look's own
    /// where it holds, else that colour darkened just far enough
    /// (#3041). Bars keep the look's colours, as on a real desk.
    static func lightRingHex(_ settings: TilingSettings) -> String {
        let ring = focusHex(settings)
            .trimmingCharacters(in: .whitespaces)
        if holdsLightRing(ring) { return ring }
        let drawn = ColorVision.composite(ring, over: lightGround)
        guard let drawn, let color = HexColor.parse(drawn) else {
            return lightInkHex
        }
        for step in 1...ringSteps {
            let scale = 1 - Double(step) / Double(ringSteps)
            let hex =
                "#"
                + [color.red, color.green, color.blue]
                .map {
                    let byte = Int(($0 * scale * 255).rounded())
                    return String(format: "%02X", byte)
                }
                .joined()
            if holdsLightRing(hex) { return hex }
        }
        return lightInkHex
    }

    private static let ringSteps = 40
    /// `SettingsTheme.lightInk`, for a ring that names no colour.
    private static let lightInkHex = "#2B3B31"
}
