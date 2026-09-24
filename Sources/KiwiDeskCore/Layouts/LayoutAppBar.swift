import CoreGraphics
import Foundation

/// Per-layout App Bar settings: whether the layout shows one, and
/// overrides of the bar's OWN fields (`AppBarStyle`). The shelf's
/// fields have no per-layout override (#1517): one shelf, one
/// edge and depth, so a layout switch never moves it.
public struct LayoutAppBar: Sendable, Equatable {
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator
    public typealias Content = AppBarStyle.Content

    /// Whether this layout displays an App Bar.
    public var enabled = true

    public var activeIndicator: ActiveIndicator?
    public var content: Content?
    public var titleCap: Int?
    public var iconSource: BarAppIconSource?
    public var groupAdjacentWindows: Bool?
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
        if let activeIndicator {
            out.activeIndicator = activeIndicator
        }
        if let content { out.content = content }
        if let titleCap { out.titleCap = titleCap }
        if let iconSource { out.iconSource = iconSource }
        if let groupAdjacentWindows {
            out.groupAdjacentWindows = groupAdjacentWindows
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
    /// A layout's App Bar look: `base`'s shelf with its bar after
    /// these overrides — the ONE body every reader of "this
    /// layout's App Bar" takes (#1517).
    public func look(on base: AppBarLook) -> AppBarLook {
        AppBarLook(shelf: base.shelf, bar: resolved(with: base.bar))
    }
}
