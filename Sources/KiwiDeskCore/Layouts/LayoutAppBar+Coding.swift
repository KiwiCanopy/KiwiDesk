import CoreGraphics
import Foundation

/// `LayoutAppBar`'s sparse `Codable`: every override is optional,
/// so an absent key inherits the global (`AppBarParityTests`
/// reflects over `Key.allCases`; a new field joins it, the
/// decoder AND the encoder, or the round-trip reds).
extension LayoutAppBar: Codable {
    typealias CodingKeys = Key

    /// JSON coding keys for LayoutAppBar (`AppBarParityTests`).
    enum Key: String, CodingKey, CaseIterable {
        case enabled
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? true
        activeIndicator = try container.decodeIfPresent(
            ActiveIndicator.self,
            forKey: .activeIndicator
        )
        content = try container.decodeIfPresent(
            Content.self,
            forKey: .content
        )
        titleCap = try container.decodeIfPresent(
            Int.self,
            forKey: .titleCap
        )
        iconSource = try container.decodeIfPresent(
            BarAppIconSource.self,
            forKey: .iconSource
        )
        groupAdjacentWindows = try container.decodeIfPresent(
            Bool.self,
            forKey: .groupAdjacentWindows
        )
        try decodeAppearance(from: container)
    }

    private mutating func decodeAppearance(
        from container: KeyedDecodingContainer<Key>
    ) throws {
        dimFactor = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .dimFactor
        )
        itemColor = try container.decodeIfPresent(
            String.self,
            forKey: .itemColor
        )
        fillColor = try container.decodeIfPresent(
            String.self,
            forKey: .fillColor
        )
        activeItemColor = try container.decodeIfPresent(
            String.self,
            forKey: .activeItemColor
        )
        highlightColor = try container.decodeIfPresent(
            String.self,
            forKey: .highlightColor
        )
        hoverFillColor = try container.decodeIfPresent(
            String.self,
            forKey: .hoverFillColor
        )
        hoverItemColor = try container.decodeIfPresent(
            String.self,
            forKey: .hoverItemColor
        )
        groupBadgeColor = try container.decodeIfPresent(
            String.self,
            forKey: .groupBadgeColor
        )
        groupBadgeTextColor = try container.decodeIfPresent(
            String.self,
            forKey: .groupBadgeTextColor
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(
            activeIndicator,
            forKey: .activeIndicator
        )
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(titleCap, forKey: .titleCap)
        try container.encodeIfPresent(
            iconSource,
            forKey: .iconSource
        )
        try container.encodeIfPresent(
            groupAdjacentWindows,
            forKey: .groupAdjacentWindows
        )
        try container.encodeIfPresent(dimFactor, forKey: .dimFactor)
        try encodeColors(into: &container)
    }

    private func encodeColors(
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        try container.encodeIfPresent(
            itemColor,
            forKey: .itemColor
        )
        try container.encodeIfPresent(fillColor, forKey: .fillColor)
        try container.encodeIfPresent(
            activeItemColor,
            forKey: .activeItemColor
        )
        try container.encodeIfPresent(
            highlightColor,
            forKey: .highlightColor
        )
        try container.encodeIfPresent(
            hoverFillColor,
            forKey: .hoverFillColor
        )
        try container.encodeIfPresent(
            hoverItemColor,
            forKey: .hoverItemColor
        )
        try container.encodeIfPresent(
            groupBadgeColor,
            forKey: .groupBadgeColor
        )
        try container.encodeIfPresent(
            groupBadgeTextColor,
            forKey: .groupBadgeTextColor
        )
    }
}
