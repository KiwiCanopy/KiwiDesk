import CoreGraphics
import Foundation

/// One-shot appearance synchronization between space bar and app bar styles
/// (`SpaceBarParityTests.copyAppearanceParity`, #293, #678 Phase 2).
extension SpaceBarStyle {
    /// JSON key spellings excluded from the copy.
    public static let copyAppearanceExclusions: Set<String> = [
        "enabled", "edge",
    ]

    /// The shared colour spellings, excluded as a class.
    public static var sharedColorKeys: Set<String> {
        let ours = Set(CodingKeys.allCases.map(\.stringValue))
        let theirs = Set(
            AppBarStyle.CodingKeys.allCases.map(\.stringValue)
        )
        return ours.intersection(theirs)
            .filter { $0.hasSuffix("_color") }
    }

    /// Shared copyable key spellings
    /// (`SpaceBarParityTests.copyAppearanceParity`).
    public static var copyAppearanceKeys: Set<String> {
        let ours = Set(CodingKeys.allCases.map(\.stringValue))
        let theirs = Set(
            AppBarStyle.CodingKeys.allCases.map(\.stringValue)
        )
        return ours.intersection(theirs)
            .subtracting(copyAppearanceExclusions)
            .subtracting(sharedColorKeys)
    }

    /// Copies shared appearance fields from AppBarStyle
    /// (`AppBarStyle.copyAppearance(from:)`).
    mutating func copyAppearance(from appBar: AppBarStyle) {
        for key in Self.copyAppearanceKeys {
            copyField(key, from: appBar)
        }
    }

    private mutating func copyField(
        _ key: String,
        from appBar: AppBarStyle
    ) {
        switch key {
        case "alignment": alignment = appBar.alignment
        case "thickness": thickness = appBar.thickness
        case "item_size": itemSize = appBar.itemSize
        case "item_gap": itemGap = appBar.itemGap
        case "font_size": fontSize = appBar.fontSize
        case "title_cap": titleCap = appBar.titleCap
        case "icon_source": iconSource = appBar.iconSource
        case "background_style":
            backgroundStyle = appBar.backgroundStyle
        case "liquid_glass":
            liquidGlass = appBar.liquidGlass
        case "background_fit":
            backgroundFit = appBar.backgroundFit
        case "active_indicator":
            activeIndicator = appBar.activeIndicator
        case "corner_roundness":
            cornerRoundness = appBar.cornerRoundness
        case "dim_factor": dimFactor = appBar.dimFactor
        default:
            // A shared key with no source line: the parity test
            // fails before this ships (`copyAppearanceParity`
            // asserts every shared key changes its field).
            break
        }
    }
}
