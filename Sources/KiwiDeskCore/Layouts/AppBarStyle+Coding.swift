import CoreGraphics
import Foundation

/// AppBarStyle Decodable implementation and CodingKeys. The
/// `Codable` conformance stays in `AppBarStyle.swift` so encode
/// is synthesized there; a property absent from `CodingKeys` is
/// silently not encoded — `AppBarParityTests` is the net.
extension AppBarStyle {
    /// JSON keys are the Lua setters minus `set_`. `CaseIterable`
    /// is load-bearing — `AppBarParityTests` reflects over
    /// `allCases`; do not drop it as "unused".
    enum CodingKeys: String, CodingKey, CaseIterable {
        case activeIndicator = "active_indicator"
        case content
        case titleCap = "title_cap"
        case iconSource = "icon_source"
        case groupAdjacentWindows = "group_adjacent_windows"
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

    /// Decodes AppBarStyle falling back to defaults for missing keys.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
        content =
            try container.decodeIfPresent(
                Content.self,
                forKey: .content
            ) ?? defaults.content
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
