import CoreGraphics
import Foundation

/// Appearance copy action from SpaceBarStyle to AppBarStyle: a
/// one-time copy of shared structural fields, never a live
/// inherit, colours excluded. Deliberately consumes
/// `SpaceBarStyle.copyAppearanceKeys` rather than minting a
/// second set (`SpaceBarParityTests` pins both directions).
extension AppBarStyle {
    /// Copies shared appearance fields from `spaceBar`
    /// (`SpaceBarStyle.copyAppearanceKeys`).
    public mutating func copyAppearance(
        from spaceBar: SpaceBarStyle
    ) {
        for key in SpaceBarStyle.copyAppearanceKeys {
            copyField(key, from: spaceBar)
        }
    }

    private mutating func copyField(
        _ key: String,
        from spaceBar: SpaceBarStyle
    ) {
        switch key {
        case "alignment": alignment = spaceBar.alignment
        case "thickness": thickness = spaceBar.thickness
        case "item_size": itemSize = spaceBar.itemSize
        case "item_gap": itemGap = spaceBar.itemGap
        case "font_size": fontSize = spaceBar.fontSize
        case "title_cap": titleCap = spaceBar.titleCap
        case "icon_source": iconSource = spaceBar.iconSource
        case "background_style":
            backgroundStyle = spaceBar.backgroundStyle
        case "liquid_glass":
            liquidGlass = spaceBar.liquidGlass
        case "background_fit":
            backgroundFit = spaceBar.backgroundFit
        case "active_indicator":
            activeIndicator = spaceBar.activeIndicator
        case "corner_roundness":
            cornerRoundness = spaceBar.cornerRoundness
        case "dim_factor": dimFactor = spaceBar.dimFactor
        default:
            // A shared key with no source line: the parity
            // test fails before this ships.
            break
        }
    }
}
