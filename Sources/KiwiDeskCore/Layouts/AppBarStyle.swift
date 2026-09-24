import CoreGraphics
import Foundation

/// The App Bar's own look and behavior (monocle, scrolling).
/// Where it sits and the look both bars share are `KiwiShelf`'s
/// (#1517); a drawing reads `AppBarLook`.
public struct AppBarStyle: Sendable, Equatable {
    public var activeIndicator: ActiveIndicator = .outline
    public var content: Content = .iconAndTitle
    /// Longest title drawn per item before tail-truncation (#1171).
    public var titleCap = 10
    /// App icon source: native image or SketchyBar App Font glyph (#294).
    public var iconSource: BarAppIconSource = .appImage
    /// Group adjacent windows of the same app with a count badge.
    public var groupAdjacentWindows = true
    /// Dim opacity for untinted inactive items (`BarAccent.untintedAlpha`).
    public var dimFactor: CGFloat = BarAccent.untintedAlpha
    /// Inactive item text and glyph colour. The colour defaults
    /// here are mirrored as examples in docs/lua-reference.md —
    /// change both.
    public var itemColor = "#EAF3EE"
    /// Background fill color (#14201CB3, #660, retuned by #755;
    /// `PaletteBarFillTests`).
    public var fillColor = "#14201CB3"
    public var activeItemColor = "#8DB354"
    public var highlightColor = "#8DB354"
    /// Hover fill color on non-active items.
    public var hoverFillColor = "#AACB5D80"
    /// Hover item text/glyph color.
    public var hoverItemColor = "#EAF3EE"
    /// Grouped window count badge colors (#955).
    public var groupBadgeColor = "#636366"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

    /// Clamps dim factor to valid range [0.05, 1.0].
    public static func clampDim(_ value: CGFloat) -> CGFloat {
        max(0.05, min(value, 1))
    }
}

extension AppBarStyle: Codable {
}
