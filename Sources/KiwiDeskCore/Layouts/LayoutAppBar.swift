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
    public typealias TabBackgroundFit =
        AppBarStyle.TabBackgroundFit
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator
    public typealias Content = AppBarStyle.Content

    /// Whether this layout shows the bar. Per-layout, never
    /// inherited — monocle and scrolling default it on.
    public var enabled = true

    // Optional overrides of the global AppBarStyle. Nil inherits.
    public var edge: AppBarEdge?
    public var alignment: AppBarStyle.BarAlignment?
    public var thickness: CGFloat?
    public var tabBackground: TabBackground?
    public var liquidGlass: Bool?
    public var tabBackgroundFit: TabBackgroundFit?
    public var activeIndicator: ActiveIndicator?
    public var boxSize: CGFloat?
    public var boxGap: CGFloat?
    public var content: Content?
    public var iconSource: BarAppIconSource?
    public var groupAdjacentWindows: Bool?
    public var fontSize: CGFloat?
    public var cornerRoundness: CGFloat?
    public var itemColor: String?
    public var fillColor: String?
    public var activeItemColor: String?
    public var highlightColor: String?
    public var hoverFillColor: String?
    public var hoverItemColor: String?
    public var groupBadgeColor: String?
    public var groupBadgeTextColor: String?

    public init() {}

    /// The concrete style this layout's bar renders with:
    /// `base` (the global style) with every non-nil override
    /// applied on top.
    public func resolved(with base: AppBarStyle) -> AppBarStyle {
        var out = base
        if let edge { out.edge = edge }
        if let alignment { out.alignment = alignment }
        // Clamp here too: an override decoded straight from a
        // hand-edited profile skips the command-path floor, and
        // `resolved(with:)` is the single funnel producing the
        // effective style — so the `minThickness` invariant holds.
        if let thickness {
            out.thickness = max(AppBarStyle.minThickness, thickness)
        }
        if let tabBackground { out.tabBackground = tabBackground }
        if let liquidGlass { out.liquidGlass = liquidGlass }
        if let tabBackgroundFit {
            out.tabBackgroundFit = tabBackgroundFit
        }
        if let activeIndicator {
            out.activeIndicator = activeIndicator
        }
        if let boxSize { out.boxSize = boxSize }
        if let boxGap { out.boxGap = boxGap }
        if let content { out.content = content }
        if let iconSource { out.iconSource = iconSource }
        if let groupAdjacentWindows {
            out.groupAdjacentWindows = groupAdjacentWindows
        }
        if let fontSize { out.fontSize = fontSize }
        if let cornerRoundness {
            out.cornerRoundness = cornerRoundness
        }
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
        case alignment
        case thickness
        case tabBackground = "tab_background"
        case liquidGlass = "liquid_glass"
        case tabBackgroundFit = "tab_background_fit"
        case activeIndicator = "active_indicator"
        case boxSize = "box_size"
        case boxGap = "box_gap"
        case content
        case iconSource = "icon_source"
        case groupAdjacentWindows = "group_adjacent_windows"
        case fontSize = "font_size"
        case cornerRoundness = "corner_roundness"
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
        tabBackground = try container.decodeIfPresent(
            TabBackground.self,
            forKey: .tabBackground
        )
        liquidGlass = try container.decodeIfPresent(
            Bool.self,
            forKey: .liquidGlass
        )
        tabBackgroundFit = try container.decodeIfPresent(
            TabBackgroundFit.self,
            forKey: .tabBackgroundFit
        )
        activeIndicator = try container.decodeIfPresent(
            ActiveIndicator.self,
            forKey: .activeIndicator
        )
        boxSize = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .boxSize
        )
        boxGap = try container.decodeIfPresent(
            CGFloat.self,
            forKey: .boxGap
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
            tabBackground,
            forKey: .tabBackground
        )
        try container.encodeIfPresent(
            liquidGlass,
            forKey: .liquidGlass
        )
        try container.encodeIfPresent(
            tabBackgroundFit,
            forKey: .tabBackgroundFit
        )
        try container.encodeIfPresent(
            activeIndicator,
            forKey: .activeIndicator
        )
        try container.encodeIfPresent(boxSize, forKey: .boxSize)
        try container.encodeIfPresent(boxGap, forKey: .boxGap)
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
