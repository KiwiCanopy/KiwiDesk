import CoreGraphics
import Foundation

/// The Space Bar's look and behavior (#293): global per-display bar listing
/// that display's Spaces. Stored as `space_bar` in profile JSON.
public struct SpaceBarStyle: Sendable, Equatable {
    public typealias BackgroundStyle = AppBarStyle.BackgroundStyle
    public typealias BackgroundFit =
        AppBarStyle.BackgroundFit
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator
    public typealias Alignment = AppBarStyle.BarAlignment

    /// On by default (QA 2026-07-19) to surface Spaces discoverability.
    public var enabled = true
    /// Absolute screen edge occupied (top by default, #660).
    public var edge: AppBarEdge = .top
    /// Item-group placement along the bar (center by default, #293 QA).
    public var alignment: Alignment = .center
    /// Depth of the reserved strip (pt).
    public var thickness: CGFloat = 32
    /// Box length along the bar (pt); 0 = auto.
    public var itemSize: CGFloat = 0
    /// Spacing between space boxes (pt).
    public var itemGap: CGFloat = 6
    /// Font size (pt); 0 = auto scale with thickness.
    public var fontSize: CGFloat = 0
    /// Max app-group glyphs per Space item before "+n" badge (#376).
    /// Default 5.
    public var glyphCap = 5
    /// App icon rendering mode: native image or App Font glyph (#294).
    public var iconSource: BarAppIconSource = .appImage
    /// Plain by default, matching App Bar (#660).
    public var backgroundStyle: BackgroundStyle = .plain
    /// Liquid Glass finish (macOS 26+). Ignored on older versions.
    public var liquidGlass: Bool = false
    /// Background fit (hug by default, QA 2026-07-19).
    public var backgroundFit: BackgroundFit = .hug
    public var activeIndicator: ActiveIndicator = .outline
    /// Corner rounding percentage (0–100) of thickness / 2.
    public var cornerRoundness: CGFloat = 50
    /// Opacity (0.05–1) on inactive spaces (`BarAccent.untintedAlpha`).
    public var dimFactor: CGFloat = BarAccent.untintedAlpha
    /// Opacity (0.05–1) of unfocused glyph on active space.
    public var activeDimFactor: CGFloat =
        BarAccent.activeUnfocusedAlpha
    /// Trailing front-app segment; off by default (ui-designer verdict 6).
    public var showFrontApp = false
    /// Front-segment character limit to prevent layout shifts. Default 25.
    public var titleCap = 25
    /// Hides empty spaces except current; off by default (verdict 4).
    public var hideEmpty = false
    /// Sticky/floating state badges on space items (#414). Default true.
    public var stickyBadge = true
    /// Drag-drop hover dwell before space spring switch (ms, #372).
    /// Default 1500.
    public var springDelay = 1500
    /// Inactive spaces accent color (#EAF3EE66).
    public var itemColor = "#EAF3EE66"
    /// Active space accent color (#8DB354).
    public var activeItemColor = "#8DB354"
    /// Focused window accent color on space bar and front-app segment (#470,
    /// #511, QA 2026-07-19; `SpaceBarAccentSeparationTests`).
    public var focusedItemColor = "#C2790A"
    /// Hover tint on non-active space items.
    public var hoverFillColor = "#AACB5D80"
    public var hoverItemColor = "#EAF3EE"
    /// Plate background fill (#14201CB3, #660, retuned by #755).
    public var fillColor = "#14201CB3"
    public var highlightColor = "#8DB354"
    /// Group count badge colors (#955).
    public var groupBadgeColor = "#636366"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

    /// True if Liquid Glass is enabled and supported on this platform.
    public var glassEnabled: Bool {
        liquidGlass && AppBarStyle.glassAvailable
    }

    /// An item paints its own box: Boxed shape, no glass finish.
    public var hasBox: Bool {
        backgroundStyle == .boxed && !glassEnabled
    }

    /// Whether plate background spans entire screen width.
    public var plateSpans: Bool {
        !hasBox && backgroundFit == .full
    }

}

/// Synthesized Codable conformance must stay in type's own file; backed by
/// `SpaceBarParityTests` and `SettingsCodingTests`.
extension SpaceBarStyle: Codable {}
