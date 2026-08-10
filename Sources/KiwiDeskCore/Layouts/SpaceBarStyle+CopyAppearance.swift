import CoreGraphics
import Foundation

/// The one-shot "Copy sizes and style to Space Bar…" action
/// (#293, rescoped with the #678 Phase 2 Bars page): the Space
/// Bar takes the App Bar's current values for the structural
/// fields the two styles share — sizes, background, indicator,
/// content-adjacent style — then stays fully independent, never
/// a live inherit.
///
/// The copied set is the **CodingKey intersection** of the two
/// styles minus deliberate exclusions, so a field added to
/// both styles joins the copy automatically (no hand list to
/// forget — `SpaceBarParityTests.copyAppearanceParity` pins
/// this):
/// - `edge` — placement is not appearance; copying it would
///   silently relocate the bar onto the App Bar's edge.
/// - `enabled` — visibility is not appearance. Inert today
///   (the global `AppBarStyle` has no `enabled` key; the App
///   Bar's toggle is per-layout), listed so the exclusion is
///   already in force the day one appears.
/// - every `*_color` key — colours are the Advanced Colours
///   area's concern (owner ruling 2026-08-02, with the Bars
///   redesign): a colours-copy, if it ships at all, lives
///   there. Derived by suffix, so a new shared colour field
///   stays out of this copy automatically.
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

    /// The shared, copyable key spellings (intersection minus
    /// exclusions minus colours) — the parity test's contract
    /// surface.
    public static var copyAppearanceKeys: Set<String> {
        let ours = Set(CodingKeys.allCases.map(\.stringValue))
        let theirs = Set(
            AppBarStyle.CodingKeys.allCases.map(\.stringValue)
        )
        return ours.intersection(theirs)
            .subtracting(copyAppearanceExclusions)
            .subtracting(sharedColorKeys)
    }

    /// Copies every shared appearance field from `appBar` —
    /// the RETIRED forward direction: the shipped button pulls
    /// the other way (`AppBarStyle.copyAppearance(from:)`,
    /// owner flip 2026-08-10), and no production path calls
    /// this any more. It stays, internal, as the parity
    /// suite's seed and the symmetric statement of the
    /// contract both directions share; if a Space Bar card
    /// ever earns its own pull button this is it, re-argued.
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
