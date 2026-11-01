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

    /// Whether a look holds the light plate (#2859 ruling 1): its
    /// item ink clears the floor on its own bar fill over the
    /// plate, and its focus ring clears the floor, out-contrasts
    /// the unfocused outline and separates from it under protan
    /// simulation. A failing look keeps the dark plate; its ink is
    /// never swapped.
    static func holdsLightPlate(_ settings: TilingSettings) -> Bool {
        let shelf = settings.kiwishelf
        let ring = focusHex(settings)
            .trimmingCharacters(in: .whitespaces)
        guard
            let bar = ColorVision.composite(
                shelf.fillColor.trimmingCharacters(in: .whitespaces),
                over: lightGround
            ),
            let drawn = ColorVision.composite(ring, over: lightGround),
            let ringContrast = ColorVision.contrast(drawn, lightGround),
            let outlineContrast = ColorVision.contrast(
                lightOutline,
                lightGround
            ),
            let separation = ColorVision.separation(drawn, lightOutline)
        else { return false }
        return plateLegible(shelf.itemColor, on: bar)
            && plateLegible(ring, on: lightGround)
            && ringContrast > outlineContrast
            && separation >= ColorVision.separationFloor
    }
}
