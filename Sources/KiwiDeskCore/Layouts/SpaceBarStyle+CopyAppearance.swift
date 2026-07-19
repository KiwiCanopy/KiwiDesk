import CoreGraphics
import Foundation

/// The one-shot "Copy App Bar appearance…" action (#293): the
/// Space Bar takes the App Bar's current values for every field
/// the two styles share, then stays fully independent — never a
/// live inherit.
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
extension SpaceBarStyle {
    /// JSON key spellings excluded from the copy.
    public static let copyAppearanceExclusions: Set<String> = [
        "enabled", "edge",
    ]

    /// The shared, copyable key spellings (intersection minus
    /// exclusions) — the parity test's contract surface.
    public static var copyAppearanceKeys: Set<String> {
        let ours = Set(CodingKeys.allCases.map(\.stringValue))
        let theirs = Set(
            AppBarStyle.CodingKeys.allCases.map(\.stringValue)
        )
        return ours.intersection(theirs)
            .subtracting(copyAppearanceExclusions)
    }

    /// Copies every shared appearance field from `appBar`. The
    /// switch is exhaustive over our own CodingKeys, so a new
    /// field cannot be silently skipped — a shared spelling
    /// must pick a source line, a space-only one lands in the
    /// keep-own list.
    public mutating func copyAppearance(from appBar: AppBarStyle) {
        for key in Self.copyAppearanceKeys {
            copyField(key, from: appBar)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private mutating func copyField(
        _ key: String,
        from appBar: AppBarStyle
    ) {
        switch key {
        case "alignment": alignment = appBar.alignment
        case "thickness": thickness = appBar.thickness
        case "box_size": boxSize = appBar.boxSize
        case "box_gap": boxGap = appBar.boxGap
        case "font_size": fontSize = appBar.fontSize
        case "icon_source": iconSource = appBar.iconSource
        case "tab_background":
            tabBackground = appBar.tabBackground
        case "tab_background_fit":
            tabBackgroundFit = appBar.tabBackgroundFit
        case "active_indicator":
            activeIndicator = appBar.activeIndicator
        case "corner_roundness":
            cornerRoundness = appBar.cornerRoundness
        case "item_color": itemColor = appBar.itemColor
        case "active_item_color":
            activeItemColor = appBar.activeItemColor
        case "hover_fill_color": hoverFillColor = appBar.hoverFillColor
        case "hover_item_color":
            hoverItemColor = appBar.hoverItemColor
        case "fill_color": fillColor = appBar.fillColor
        case "highlight_color":
            highlightColor = appBar.highlightColor
        case "group_badge_color":
            groupBadgeColor = appBar.groupBadgeColor
        case "group_badge_text_color":
            groupBadgeTextColor = appBar.groupBadgeTextColor
        default:
            // A shared key with no source line: the parity test
            // fails before this ships (`copyAppearanceParity`
            // asserts every shared key changes its field).
            break
        }
    }
}
