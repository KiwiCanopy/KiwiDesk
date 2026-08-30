import CoreGraphics
import Foundation

/// Global look and behavior for app bars (monocle, scrolling).
public struct AppBarStyle: Sendable, Equatable {
    /// Screen edge occupied by the bar (bottom by default, #293, #660).
    public var edge: AppBarEdge = .bottom
    /// Item group alignment along the bar (center by default).
    public var alignment: BarAlignment = .center
    /// Depth of the reserved strip (pt).
    public var thickness: CGFloat = 32
    /// Background plate style (plain by default, #660).
    public var backgroundStyle: BackgroundStyle = .plain
    /// Liquid Glass material (macOS 26+, #390).
    public var liquidGlass: Bool = false
    /// Background fit (hug by default, QA 2026-07-19).
    public var backgroundFit: BackgroundFit = .hug
    public var activeIndicator: ActiveIndicator = .outline
    /// Item length along the bar in pt (0 = auto per content).
    public var itemSize: CGFloat = 0
    /// Spacing between item boxes in pt.
    public var itemGap: CGFloat = 6
    public var content: Content = .iconAndTitle
    /// Longest title drawn per item before tail-truncation. Default 25
    /// (owner 2026-08-19).
    public var titleCap = 25
    /// App icon source: native image or SketchyBar App Font glyph (#294).
    public var iconSource: BarAppIconSource = .appImage
    /// Group adjacent windows of the same app with a count badge.
    public var groupAdjacentWindows = true
    /// Font size (0 = auto scale with thickness).
    public var fontSize: CGFloat = 0
    /// Corner rounding percentage (0–100) of thickness / 2.
    public var cornerRoundness: CGFloat = 50
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

    /// Concrete corner radius in pt for a given thickness.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }

    /// Clamps dim factor to valid range [0.05, 1.0].
    public static func clampDim(_ value: CGFloat) -> CGFloat {
        max(0.05, min(value, 1))
    }

    /// True if Liquid Glass is enabled and supported on this platform.
    public var glassEnabled: Bool {
        liquidGlass && Self.glassAvailable
    }

    /// True if item paints its own boxed background without glass.
    public var hasBox: Bool {
        backgroundStyle == .boxed && !glassEnabled
    }

    /// True if the plate spans edge-to-edge — the SETTINGS
    /// PREVIEWS' one copy of the spans rule; the live bars resolve
    /// one layer down in `BarPlate.frame` (which adds the hug→full
    /// overflow fallback), so a retune touches this and `BarPlate`
    /// together. `SpaceBarStyle.plateSpans` is the twin.
    public var plateSpans: Bool {
        !hasBox && backgroundFit == .full
    }
}

extension AppBarStyle: Codable {
}
