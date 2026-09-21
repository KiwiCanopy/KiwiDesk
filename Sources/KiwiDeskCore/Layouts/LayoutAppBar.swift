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
    public var outerMargin: CGFloat?
    public var innerMargin: CGFloat?
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
        if let thickness {
            out.thickness = max(AppBarStyle.minThickness, thickness)
        }
        if let outerMargin {
            out.outerMargin = max(AppBarStyle.minMargin, outerMargin)
        }
        if let innerMargin {
            out.innerMargin = max(AppBarStyle.minMargin, innerMargin)
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
