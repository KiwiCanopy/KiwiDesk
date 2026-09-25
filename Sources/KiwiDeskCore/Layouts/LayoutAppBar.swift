import CoreGraphics
import Foundation

/// Per-layout App Bar settings: whether the layout shows one, and
/// overrides of the bar's OWN fields (`AppBarStyle`). The shelf's
/// fields — colours, symbol style and dim included — have no
/// per-layout override (#1517): one shelf, one look, so a layout
/// switch never changes it.
public struct LayoutAppBar: Sendable, Equatable {
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator
    public typealias Content = AppBarStyle.Content

    /// Whether this layout displays an App Bar.
    public var enabled = true

    public var activeIndicator: ActiveIndicator?
    public var content: Content?
    public var titleCap: Int?
    public var groupAdjacentWindows: Bool?

    public init() {}

    /// Merges layout-specific overrides onto base global AppBarStyle.
    public func resolved(with base: AppBarStyle) -> AppBarStyle {
        var out = base
        if let activeIndicator {
            out.activeIndicator = activeIndicator
        }
        if let content { out.content = content }
        if let titleCap { out.titleCap = titleCap }
        if let groupAdjacentWindows {
            out.groupAdjacentWindows = groupAdjacentWindows
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
