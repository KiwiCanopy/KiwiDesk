import CoreGraphics
import Foundation

/// SpaceBarStyle Decodable implementation and CodingKeys
/// (`SpaceBarParityTests`).
extension SpaceBarStyle {
    /// JSON coding keys for SpaceBarStyle (`SpaceBarParityTests`).
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case edge
        case glyphSpan = "glyph_span"
        case groupAdjacentWindows = "group_adjacent_windows"
        case expandActiveSpace = "expand_active_space"
        case showHoverTitles = "show_hover_titles"
        case glyphGap = "glyph_gap"
        case inactiveContent = "inactive_content"
        case itemLabel = "item_label"
        case frontAppTitleCap = "front_app_title_cap"
        case activeIndicator = "active_indicator"
        case activeDimFactor = "active_dim_factor"
        case showFrontApp = "show_front_app"
        case hideEmpty = "hide_empty"
        case stickyBadge = "sticky_badge"
        case springDelay = "spring_delay"
        case focusedItemColor = "focused_item_color"
        case focusedHighlightColor = "focused_highlight_color"
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
        glyphSpan =
            try container.decodeIfPresent(
                Int.self,
                forKey: .glyphSpan
            ) ?? defaults.glyphSpan
        groupAdjacentWindows =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .groupAdjacentWindows
            ) ?? defaults.groupAdjacentWindows
        expandActiveSpace =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .expandActiveSpace
            ) ?? defaults.expandActiveSpace
        showHoverTitles =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .showHoverTitles
            ) ?? defaults.showHoverTitles
        glyphGap = Self.clampGlyphGap(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .glyphGap
            ) ?? defaults.glyphGap
        )
        inactiveContent =
            try container.decodeIfPresent(
                InactiveContent.self,
                forKey: .inactiveContent
            ) ?? defaults.inactiveContent
        itemLabel =
            try container.decodeIfPresent(
                ItemLabel.self,
                forKey: .itemLabel
            ) ?? defaults.itemLabel
        frontAppTitleCap =
            try container.decodeIfPresent(
                Int.self,
                forKey: .frontAppTitleCap
            ) ?? defaults.frontAppTitleCap
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
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
        focusedItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .focusedItemColor
            ) ?? defaults.focusedItemColor
        focusedHighlightColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .focusedHighlightColor
            ) ?? defaults.focusedHighlightColor
    }
}
