import CoreGraphics
import Foundation

/// SpaceBarStyle Decodable implementation and CodingKeys
/// (`SpaceBarParityTests`).
extension SpaceBarStyle {
    /// JSON coding keys for SpaceBarStyle (`SpaceBarParityTests`).
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case edge
        case alignment
        case thickness
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case fontSize = "font_size"
        case glyphCap = "glyph_cap"
        case titleCap = "title_cap"
        case iconSource = "icon_source"
        case backgroundStyle = "background_style"
        case liquidGlass = "liquid_glass"
        case backgroundFit = "background_fit"
        case activeIndicator = "active_indicator"
        case cornerRoundness = "corner_roundness"
        case dimFactor = "dim_factor"
        case activeDimFactor = "active_dim_factor"
        case showFrontApp = "show_front_app"
        case hideEmpty = "hide_empty"
        case stickyBadge = "sticky_badge"
        case springDelay = "spring_delay"
        case itemColor = "item_color"
        case activeItemColor = "active_item_color"
        case focusedItemColor = "focused_item_color"
        case hoverFillColor = "hover_fill_color"
        case hoverItemColor = "hover_item_color"
        case fillColor = "fill_color"
        case highlightColor = "highlight_color"
        case groupBadgeColor = "group_badge_color"
        case groupBadgeTextColor = "group_badge_text_color"
    }

    /// Decodes SpaceBarStyle falling back to defaults for missing keys.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? defaults.enabled
        edge =
            try container.decodeIfPresent(
                AppBarEdge.self,
                forKey: .edge
            ) ?? defaults.edge
        alignment =
            try container.decodeIfPresent(
                Alignment.self,
                forKey: .alignment
            ) ?? defaults.alignment
        thickness = max(
            AppBarStyle.minThickness,
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
        )
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
        fontSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .fontSize
            ) ?? defaults.fontSize
        glyphCap =
            try container.decodeIfPresent(
                Int.self,
                forKey: .glyphCap
            ) ?? defaults.glyphCap
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
        cornerRoundness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRoundness
            ) ?? defaults.cornerRoundness
        dimFactor = AppBarStyle.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .dimFactor
            ) ?? defaults.dimFactor
        )
        activeDimFactor = AppBarStyle.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .activeDimFactor
            ) ?? defaults.activeDimFactor
        )
        showFrontApp =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .showFrontApp
            ) ?? defaults.showFrontApp
        hideEmpty =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .hideEmpty
            ) ?? defaults.hideEmpty
        stickyBadge =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .stickyBadge
            ) ?? defaults.stickyBadge
        springDelay =
            try container.decodeIfPresent(
                Int.self,
                forKey: .springDelay
            ) ?? defaults.springDelay
        try decodeColors(from: container)
    }

    private mutating func decodeColors(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        itemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .itemColor
            ) ?? defaults.itemColor
        activeItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeItemColor
            ) ?? defaults.activeItemColor
        focusedItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .focusedItemColor
            ) ?? defaults.focusedItemColor
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
        fillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .fillColor
            ) ?? defaults.fillColor
        highlightColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .highlightColor
            ) ?? defaults.highlightColor
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
