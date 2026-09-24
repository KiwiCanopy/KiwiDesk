import CoreGraphics
import Foundation

/// The Space Bar's own look and behavior (#293): per-display bar
/// listing that display's Spaces. Stored as `space_bar` in profile
/// JSON; where it sits and the look both bars share are
/// `KiwiShelf`'s (#1517), and a drawing reads `SpaceBarLook`.
public struct SpaceBarStyle: Sendable, Equatable {
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator

    /// On by default (QA 2026-07-19) to surface Spaces discoverability.
    public var enabled = true
    /// Max app-group glyphs per Space item before "+n" badge (#376).
    /// Default 5.
    public var glyphCap = 5
    /// App icon rendering mode: native image or App Font glyph (#294).
    public var iconSource: BarAppIconSource = .appImage
    public var activeIndicator: ActiveIndicator = .outline
    /// Opacity (0.05–1) on inactive spaces (`BarAccent.untintedAlpha`).
    public var dimFactor: CGFloat = BarAccent.untintedAlpha
    /// Opacity (0.05–1) of unfocused glyph on active space.
    public var activeDimFactor: CGFloat =
        BarAccent.activeUnfocusedAlpha
    /// Trailing front-app segment; off by default (ui-designer verdict 6).
    public var showFrontApp = false
    /// Front-app segment title length in characters, before
    /// tail-truncation — keeps the bar from shifting (#1517
    /// renamed it from `title_cap`).
    public var frontAppTitleCap = 10
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
}

/// Synthesized Codable conformance must stay in the type's own
/// file (cross-file conformances get no synthesized `encode`,
/// forcing the mirrored list parity-tests.md bans). The OPPOSITE
/// placement from `TilingSettings+Coding` is deliberate — do not
/// harmonize; `SpaceBarParityTests` and `SettingsCodingTests`
/// backstop the residual hazard.
extension SpaceBarStyle: Codable {}
