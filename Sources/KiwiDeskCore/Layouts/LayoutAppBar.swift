import CoreGraphics
import Foundation

/// Per-layout App Bar settings: how the layout shows its bar, and
/// overrides of the bar's OWN fields (`AppBarStyle`). The shelf's
/// fields — colours, glyph style and dim included — have no
/// per-layout override (#1517): one shelf, one look, so a layout
/// switch never changes it.
public struct LayoutAppBar: Sendable, Equatable {
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator

    /// Whether this layout's App Bar stays shown, hides to a mark,
    /// or shows only on its shortcut (#761) — the layout's own
    /// value, since only some layouts carry the bar.
    public var visibility: ShelfVisibility = .always

    public var activeIndicator: ActiveIndicator?
    public var titleCap: Int?
    public var groupAdjacentWindows: Bool?

    public init() {}

    /// Merges layout-specific overrides onto base global AppBarStyle.
    public func resolved(with base: AppBarStyle) -> AppBarStyle {
        var out = base
        if let activeIndicator {
            out.activeIndicator = activeIndicator
        }
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
        AppBarLook(
            shelf: base.shelf,
            bar: resolved(with: base.bar),
            sheen: base.sheen
        )
    }
}
