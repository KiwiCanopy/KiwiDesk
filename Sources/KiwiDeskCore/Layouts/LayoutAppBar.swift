import CoreGraphics
import Foundation

/// Per-layout App Bar settings and overrides (`AppBarStyle`).
public struct LayoutAppBar: Sendable, Equatable {
    public typealias BackgroundStyle = AppBarStyle.BackgroundStyle
    public typealias BackgroundFit =
        AppBarStyle.BackgroundFit
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator
    public typealias Content = AppBarStyle.Content

    /// Whether this layout displays an App Bar.
    public var enabled = true

    public var edge: AppBarEdge?
    public var alignment: AppBarStyle.BarAlignment?
    public var thickness: CGFloat?
    public var backgroundStyle: BackgroundStyle?
    public var liquidGlass: Bool?
    public var backgroundFit: BackgroundFit?
    public var activeIndicator: ActiveIndicator?
    public var itemSize: CGFloat?
    public var itemGap: CGFloat?
    public var content: Content?
    public var titleCap: Int?
    public var iconSource: BarAppIconSource?
    public var groupAdjacentWindows: Bool?
    public var fontSize: CGFloat?
    public var cornerRoundness: CGFloat?
    public var dimFactor: CGFloat?
    public var itemColor: String?
    public var fillColor: String?
    public var activeItemColor: String?
    public var highlightColor: String?
    public var hoverFillColor: String?
    public var hoverItemColor: String?
    public var groupBadgeColor: String?
    public var groupBadgeTextColor: String?

    public init() {}

    /// Merges layout-specific overrides onto base global AppBarStyle.
    public func resolved(with base: AppBarStyle) -> AppBarStyle {
        var out = base
        if let edge { out.edge = edge }
        if let alignment { out.alignment = alignment }
        // Clamp here too: an override decoded from a hand-edited
        // profile skips the command-path floor, and this is the
        // single funnel producing the effective style — so the
        // `minThickness` invariant holds.
        if let thickness {
            out.thickness = max(AppBarStyle.minThickness, thickness)
        }
        if let backgroundStyle { out.backgroundStyle = backgroundStyle }
        if let liquidGlass { out.liquidGlass = liquidGlass }
        if let backgroundFit {
            out.backgroundFit = backgroundFit
        }
        if let activeIndicator {
            out.activeIndicator = activeIndicator
        }
        if let itemSize { out.itemSize = itemSize }
        if let itemGap { out.itemGap = itemGap }
        if let content { out.content = content }
        if let titleCap { out.titleCap = titleCap }
        if let iconSource { out.iconSource = iconSource }
        if let groupAdjacentWindows {
            out.groupAdjacentWindows = groupAdjacentWindows
        }
        if let fontSize { out.fontSize = fontSize }
        if let cornerRoundness {
            out.cornerRoundness = cornerRoundness
        }
        if let dimFactor { out.dimFactor = dimFactor }
        if let itemColor { out.itemColor = itemColor }
        if let fillColor { out.fillColor = fillColor }
        if let activeItemColor {
            out.activeItemColor = activeItemColor
        }
        if let highlightColor {
            out.highlightColor = highlightColor
        }
        if let hoverFillColor { out.hoverFillColor = hoverFillColor }
        if let hoverItemColor {
            out.hoverItemColor = hoverItemColor
        }
        if let groupBadgeColor {
            out.groupBadgeColor = groupBadgeColor
        }
        if let groupBadgeTextColor {
            out.groupBadgeTextColor = groupBadgeTextColor
        }
        return out
    }
}

extension LayoutAppBar: Codable {
    typealias CodingKeys = Key

    /// JSON coding keys. `CaseIterable` is load-bearing:
    /// `AppBarParityTests` reflects over `allCases` to prove every
    /// field has a key — do not drop it as "unused".
    enum Key: String, CodingKey, CaseIterable {
        case enabled
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? true
        edge = try container.decodeIfPresent(
            AppBarEdge.self,
            forKey: .edge
        )
        alignment = try container.decodeIfPresent(
            AppBarStyle.BarAlignment.self,
            forKey: .alignment
        )
        thickness = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .thickness
        )
        backgroundStyle = try container.decodeIfPresent(
            BackgroundStyle.self,
            forKey: .backgroundStyle
        )
        liquidGlass = try container.decodeIfPresent(
            Bool.self,
            forKey: .liquidGlass
        )
        backgroundFit = try container.decodeIfPresent(
            BackgroundFit.self,
            forKey: .backgroundFit
        )
        activeIndicator = try container.decodeIfPresent(
            ActiveIndicator.self,
            forKey: .activeIndicator
        )
        itemSize = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .itemSize
        )
        itemGap = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .itemGap
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
        fontSize = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .fontSize
        )
        cornerRoundness = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .cornerRoundness
        )
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
        try container.encodeIfPresent(edge, forKey: .edge)
        try container.encodeIfPresent(
            alignment,
            forKey: .alignment
        )
        try container.encodeIfPresent(
            thickness,
            forKey: .thickness
        )
        try container.encodeIfPresent(
            backgroundStyle,
            forKey: .backgroundStyle
        )
        try container.encodeIfPresent(
            liquidGlass,
            forKey: .liquidGlass
        )
        try container.encodeIfPresent(
            backgroundFit,
            forKey: .backgroundFit
        )
        try container.encodeIfPresent(
            activeIndicator,
            forKey: .activeIndicator
        )
        try container.encodeIfPresent(itemSize, forKey: .itemSize)
        try container.encodeIfPresent(itemGap, forKey: .itemGap)
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
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(
            cornerRoundness,
            forKey: .cornerRoundness
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
