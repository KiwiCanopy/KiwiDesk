import CoreGraphics
import Foundation

/// `AppBarStyle`'s wire form, split out of the type's own file at
/// the 350-line ceiling (AGENTS.md §2.1) — the same arrangement
/// `SpaceBarStyle+Coding.swift` already carries, and for the same
/// reason.
///
/// The `Codable` conformance deliberately stays in
/// `AppBarStyle.swift`: Swift only synthesizes `encode(to:)`
/// where the conformance sits, so keeping it there leaves encode
/// generated and makes a new stored property impossible to drop
/// from the wire by forgetting a line. Moving the conformance
/// here is a compile error rather than a quiet regression.
///
/// Sparse by design — every field falls back to `defaults`, so a
/// profile written before a field existed still loads.
extension AppBarStyle {
    /// JSON keys are the Lua setters (`app_bar.set_*`) minus the
    /// `set_` verb — the `app_bar` nesting carries the namespace.
    /// `CaseIterable` is load-bearing: the parity test
    /// (`AppBarParityTests`) reflects over `allCases` to prove
    /// every field has a key — do not drop it as "unused".
    enum CodingKeys: String, CodingKey, CaseIterable {
        case edge
        case alignment
        case thickness
        case backgroundStyle = "background_style"
        case liquidGlass = "liquid_glass"
        case backgroundFit = "background_fit"
        case activeIndicator = "active_indicator"
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case content
        case titleCap = "title_cap"
        case iconSource = "icon_source"
        case groupAdjacentWindows = "group_adjacent_windows"
        case fontSize = "font_size"
        case cornerRoundness = "corner_roundness"
        case dimFactor = "dim_factor"
        case itemColor = "item_color"
        case fillColor = "fill_color"
        case activeItemColor = "active_item_color"
        case highlightColor = "highlight_color"
        case hoverFillColor = "hover_fill_color"
        case hoverItemColor = "hover_item_color"
        case groupBadgeColor = "group_badge_color"
        case groupBadgeTextColor = "group_badge_text_color"
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        edge =
            try container.decodeIfPresent(
                AppBarEdge.self,
                forKey: .edge
            ) ?? defaults.edge
        alignment =
            try container.decodeIfPresent(
                BarAlignment.self,
                forKey: .alignment
            ) ?? defaults.alignment
        thickness = max(
            Self.minThickness,
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
        )
        backgroundStyle =
            try container.decodeIfPresent(
                BackgroundStyle.self,
                forKey: .backgroundStyle
            ) ?? defaults.backgroundStyle
        liquidGlass =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .liquidGlass
            ) ?? defaults.liquidGlass
        backgroundFit =
            try container.decodeIfPresent(
                BackgroundFit.self,
                forKey: .backgroundFit
            ) ?? defaults.backgroundFit
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
        itemSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .itemSize
            ) ?? defaults.itemSize
        itemGap =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .itemGap
            ) ?? defaults.itemGap
        // Decoded as a raw string and folded through
        // `Content.decoded`, never as `Content.self`: a profile
        // saved with a retired app-name spelling would otherwise
        // THROW here and take every other bar setting in this
        // struct down with it.
        content =
            try container.decodeIfPresent(
                String.self,
                forKey: .content
            ).flatMap(Content.decoded) ?? defaults.content
        titleCap =
            try container.decodeIfPresent(
                Int.self,
                forKey: .titleCap
            ) ?? defaults.titleCap
        iconSource =
            try container.decodeIfPresent(
                BarAppIconSource.self,
                forKey: .iconSource
            ) ?? defaults.iconSource
        groupAdjacentWindows =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .groupAdjacentWindows
            ) ?? defaults.groupAdjacentWindows
        try decodeAppearance(from: container)
    }

    private mutating func decodeAppearance(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        fontSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .fontSize
            ) ?? defaults.fontSize
        cornerRoundness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRoundness
            ) ?? defaults.cornerRoundness
        dimFactor = Self.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .dimFactor
            ) ?? defaults.dimFactor
        )
        itemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .itemColor
            ) ?? defaults.itemColor
        fillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .fillColor
            ) ?? defaults.fillColor
        activeItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeItemColor
            ) ?? defaults.activeItemColor
        highlightColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .highlightColor
            ) ?? defaults.highlightColor
        hoverFillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverFillColor
            ) ?? defaults.hoverFillColor
        hoverItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverItemColor
            ) ?? defaults.hoverItemColor
        groupBadgeColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .groupBadgeColor
            ) ?? defaults.groupBadgeColor
        groupBadgeTextColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .groupBadgeTextColor
            ) ?? defaults.groupBadgeTextColor
    }
}
