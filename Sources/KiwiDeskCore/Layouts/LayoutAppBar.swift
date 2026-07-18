import CoreGraphics
import Foundation

/// A layout's own bar settings, nested as `app_bar` under the
/// layout (`layout.monocle.app_bar`, `layout.scroll.app_bar`).
///
/// `enabled` is the only always-present, layout-specific value —
/// whether this layout shows a bar at all. Every look field is
/// an *optional override*: nil means "inherit the global
/// `AppBarStyle`" (shown gray in the GUI), a value means "override
/// it just for this layout" (shown black). `resolved(with:)`
/// merges the two into the concrete style the bar renders with.
public struct LayoutAppBar: Sendable, Equatable {
    public typealias TabBackground = AppBarStyle.TabBackground
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator
    public typealias Content = AppBarStyle.Content

    /// Whether this layout shows the bar. Per-layout, never
    /// inherited — monocle and scrolling default it on.
    public var enabled = true

    // Optional overrides of the global AppBarStyle. Nil inherits.
    public var edge: AppBarEdge?
    public var thickness: CGFloat?
    public var tabBackground: TabBackground?
    public var activeIndicator: ActiveIndicator?
    public var itemSize: CGFloat?
    public var itemGap: CGFloat?
    public var content: Content?
    public var iconSource: BarAppIconSource?
    public var groupAdjacentWindows: Bool?
    public var fontSize: CGFloat?
    public var cornerRoundness: CGFloat?
    public var textColor: String?
    public var boxColor: String?
    public var activeTextColor: String?
    public var activeBoxColor: String?
    public var highlightColor: String?
    public var hoverColor: String?
    public var hoverTextColor: String?
    public var backgroundColor: String?
    public var groupBadgeColor: String?
    public var groupBadgeTextColor: String?

    public init() {}

    /// The concrete style this layout's bar renders with:
    /// `base` (the global style) with every non-nil override
    /// applied on top.
    public func resolved(with base: AppBarStyle) -> AppBarStyle {
        var out = base
        if let edge { out.edge = edge }
        if let thickness { out.thickness = thickness }
        if let tabBackground { out.tabBackground = tabBackground }
        if let activeIndicator {
            out.activeIndicator = activeIndicator
        }
        if let itemSize { out.itemSize = itemSize }
        if let itemGap { out.itemGap = itemGap }
        if let content { out.content = content }
        if let iconSource { out.iconSource = iconSource }
        if let groupAdjacentWindows {
            out.groupAdjacentWindows = groupAdjacentWindows
        }
        if let fontSize { out.fontSize = fontSize }
        if let cornerRoundness {
            out.cornerRoundness = cornerRoundness
        }
        if let textColor { out.textColor = textColor }
        if let boxColor { out.boxColor = boxColor }
        if let activeTextColor {
            out.activeTextColor = activeTextColor
        }
        if let activeBoxColor {
            out.activeBoxColor = activeBoxColor
        }
        if let highlightColor {
            out.highlightColor = highlightColor
        }
        if let hoverColor { out.hoverColor = hoverColor }
        if let hoverTextColor {
            out.hoverTextColor = hoverTextColor
        }
        if let backgroundColor {
            out.backgroundColor = backgroundColor
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

// MARK: - Codable

extension LayoutAppBar: Codable {
    /// Same JSON spelling as `AppBarStyle` (the Lua setters), plus
    /// `enabled`. Only `enabled` and the set overrides are
    /// written; inherited fields stay absent.
    typealias CodingKeys = Key

    /// `CaseIterable` is load-bearing: the parity test
    /// (`AppBarParityTests`) reflects over `allCases` to prove
    /// every field has a key — do not drop it as "unused".
    enum Key: String, CodingKey, CaseIterable {
        case enabled
        case edge
        case thickness
        case tabBackground = "tab_background"
        case activeIndicator = "active_indicator"
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case content
        case iconSource = "icon_source"
        case groupAdjacentWindows = "group_adjacent_windows"
        case fontSize = "font_size"
        case cornerRoundness = "corner_roundness"
        case textColor = "text_color"
        case boxColor = "box_color"
        case activeTextColor = "active_text_color"
        case activeBoxColor = "active_box_color"
        case highlightColor = "highlight_color"
        case hoverColor = "hover_color"
        case hoverTextColor = "hover_text_color"
        case backgroundColor = "background_color"
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
        thickness = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .thickness
        )
        tabBackground = try container.decodeIfPresent(
            TabBackground.self,
            forKey: .tabBackground
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
        textColor = try container.decodeIfPresent(
            String.self,
            forKey: .textColor
        )
        boxColor = try container.decodeIfPresent(
            String.self,
            forKey: .boxColor
        )
        activeTextColor = try container.decodeIfPresent(
            String.self,
            forKey: .activeTextColor
        )
        activeBoxColor = try container.decodeIfPresent(
            String.self,
            forKey: .activeBoxColor
        )
        highlightColor = try container.decodeIfPresent(
            String.self,
            forKey: .highlightColor
        )
        hoverColor = try container.decodeIfPresent(
            String.self,
            forKey: .hoverColor
        )
        hoverTextColor = try container.decodeIfPresent(
            String.self,
            forKey: .hoverTextColor
        )
        backgroundColor = try container.decodeIfPresent(
            String.self,
            forKey: .backgroundColor
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
            thickness,
            forKey: .thickness
        )
        try container.encodeIfPresent(
            tabBackground,
            forKey: .tabBackground
        )
        try container.encodeIfPresent(
            activeIndicator,
            forKey: .activeIndicator
        )
        try container.encodeIfPresent(itemSize, forKey: .itemSize)
        try container.encodeIfPresent(itemGap, forKey: .itemGap)
        try container.encodeIfPresent(content, forKey: .content)
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
        try encodeColors(into: &container)
    }

    private func encodeColors(
        into container: inout KeyedEncodingContainer<Key>
    ) throws {
        try container.encodeIfPresent(
            textColor,
            forKey: .textColor
        )
        try container.encodeIfPresent(boxColor, forKey: .boxColor)
        try container.encodeIfPresent(
            activeTextColor,
            forKey: .activeTextColor
        )
        try container.encodeIfPresent(
            activeBoxColor,
            forKey: .activeBoxColor
        )
        try container.encodeIfPresent(
            highlightColor,
            forKey: .highlightColor
        )
        try container.encodeIfPresent(
            hoverColor,
            forKey: .hoverColor
        )
        try container.encodeIfPresent(
            hoverTextColor,
            forKey: .hoverTextColor
        )
        try container.encodeIfPresent(
            backgroundColor,
            forKey: .backgroundColor
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
