import CoreGraphics
import Foundation

/// The one-shot "Copy sizes and style from Space Bar…" action —
/// the REVERSED twin of `SpaceBarStyle.copyAppearance(from:)`
/// (owner flipped the direction 2026-08-10: the button sits at
/// the App Bar card's tail, and a button there should fill in
/// THIS card's bar from the one already configured, not push
/// outward). Same contract: a one-time copy of the structural
/// fields the two styles share, never a live inherit, colours
/// excluded (Advanced Colours owns any colours-copy).
///
/// The copied set is `SpaceBarStyle.copyAppearanceKeys` — the
/// intersection is symmetric, so this direction deliberately
/// consumes the SAME set rather than minting a second one; the
/// exclusions and the colour class live there once.
/// `SpaceBarParityTests` pins that every shared key changes a
/// field in BOTH directions.
extension AppBarStyle {
    /// Copies every shared appearance field from `spaceBar`.
    public mutating func copyAppearance(
        from spaceBar: SpaceBarStyle
    ) {
        for key in SpaceBarStyle.copyAppearanceKeys {
            copyField(key, from: spaceBar)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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
