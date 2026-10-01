import CoreGraphics
import Foundation

/// The Space Bar's own look and behavior (#293): per-display bar
/// listing that display's Spaces. Stored as `space_bar` in profile
/// JSON; the look both bars share is `KiwiShelf`'s (#1517), and
/// a drawing reads `SpaceBarLook`.
public struct SpaceBarStyle: Sendable, Equatable {
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator

    /// On by default (QA 2026-07-19) to surface Spaces discoverability.
    public var enabled = true
    /// The screen edge the bar sits on (top). The App Bar on the
    /// same edge shares one shelf with it; on another, each bar
    /// is its own (#1731).
    public var edge: AppBarEdge = .top
    /// Max glyphs per Space item before "+n" badge (#376).
    /// Default 5.
    public var glyphSpan = 5
    /// Whether adjacent windows of one app share a glyph and a
    /// count badge (#1725); off draws one glyph per window.
    public var groupAdjacentWindows = true
    /// Extra room (pt) between app glyph cells inside a Space
    /// item, and before its `+n` badge (#1689); 0 abuts them. A
    /// drawing reads `resolvedGlyphGap`.
    public var glyphGap: CGFloat = 0
    /// What a Space its screen does not show draws (#1683); the
    /// default keeps every Space's glyphs.
    public var inactiveContent: InactiveContent = .apps
    /// What a Space item names its Space by (#1535); the
    /// default keeps the identifier.
    public var itemLabel: ItemLabel = .identifier
    public var activeIndicator: ActiveIndicator = .outline
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
    /// Focused window accent color on space bar and front-app segment (#470,
    /// #511, QA 2026-07-19; `SpaceBarAccentSeparationTests`).
    public var focusedItemColor = "#C2790A"
    /// The front-app chip's active indicator colour (#1856); empty
    /// is Automatic, the front app's own `focusedItemColor`, as
    /// every bundled palette pairs a text with its ring. A drawing
    /// reads `resolvedFocusedHighlightColor`.
    public var focusedHighlightColor = ""

    public init() {}

    /// The front chip's indicator as drawn: Automatic follows the
    /// focused item colour.
    public var resolvedFocusedHighlightColor: String {
        focusedHighlightColor.isEmpty
            ? focusedItemColor : focusedHighlightColor
    }

    /// A Space item's content while its screen shows another
    /// Space (#1683). The glyph span still sizes the shown Space.
    public enum InactiveContent: String, Sendable, Codable,
        CaseIterable
    {
        /// Its app glyphs, as the shown Space draws them.
        case apps
        /// Its identifier, its window count a disc on its corner.
        case count
    }

    /// What names a Space item (#1535). An option, never a
    /// fallback: the identifier ladder stays the default.
    public enum ItemLabel: String, Sendable, Codable, CaseIterable {
        /// Its icon, number or name (`spaceIdentifier`).
        case identifier
        /// Its current layout's `LayoutMode.symbol`.
        case layout
    }
}

/// Synthesized Codable conformance must stay in the type's own
/// file (cross-file conformances get no synthesized `encode`,
/// forcing the mirrored list parity-tests.md bans). The OPPOSITE
/// placement from `TilingSettings+Coding` is deliberate — do not
/// harmonize; `SpaceBarParityTests` and `SettingsCodingTests`
/// backstop the residual hazard.
extension SpaceBarStyle: Codable {}
