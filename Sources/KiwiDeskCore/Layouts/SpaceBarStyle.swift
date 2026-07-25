import CoreGraphics
import Foundation

/// The Space Bar's look and behavior (#293): one bar per display
/// listing that display's Spaces, layout-independent. Stored
/// top-level as `space_bar` in profile JSON, set from Lua via
/// `space_bar.set_*`.
///
/// Deliberately **global-only** — the bar exists outside every
/// layout, so there is no per-layout override mirror (and no
/// parity surface for one). `enabled` lives here for the same
/// reason: no layout owns the bar.
///
/// The two-accent model is the bar's signature: `itemColor`
/// paints inactive spaces, `activeItemColor` the active space's
/// identifier and glyphs, and `focusedItemColor` the focused
/// window — its glyph inside the active space AND the front-app
/// segment (spaces.lua's `space_focused_window`).
public struct SpaceBarStyle: Sendable, Equatable {
    public typealias TabBackground = AppBarStyle.TabBackground
    public typealias TabBackgroundFit =
        AppBarStyle.TabBackgroundFit
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator
    public typealias Alignment = AppBarStyle.BarAlignment

    /// On by default (QA 2026-07-19): the bar is the only
    /// surface where KiwiDesk's virtual spaces are visible at
    /// all — without it a new user may never discover the
    /// concept. macOS's own Spaces have Mission Control; ours
    /// have only this.
    public var enabled = true
    /// The absolute screen edge the bar occupies. When it
    /// matches the App Bar's edge, the Space Bar is always
    /// screen-facing and the App Bar window-facing (space-first
    /// reservation) — never a conflict.
    public var edge: AppBarEdge = .left
    /// Item-group placement along the bar (#293 QA); one
    /// shared default with the App Bar — the bar's pre-QA
    /// de-facto start anchoring was an omission, not a
    /// decision.
    public var alignment: Alignment = .center
    /// Depth of the reserved strip (pt); aligned with the App
    /// Bar default.
    public var thickness: CGFloat = 32
    /// Box length along the bar (pt); 0 (default) = auto.
    public var boxSize: CGFloat = 0
    /// Spacing between space boxes (pt).
    public var boxGap: CGFloat = 6
    /// 0 (default) = auto: text scales with the bar thickness.
    public var fontSize: CGFloat = 0
    /// Max app-group glyphs rendered per Space item (#376);
    /// grouping runs first, then this cap, and any further groups
    /// fold into the trailing "+n" badge. Read through
    /// `resolvedGlyphCap`, which clamps to `glyphCapRange`.
    /// Default 5 (the shipped #293 value).
    public var glyphCap = 5
    /// How app glyphs are drawn (#294): the native app image or
    /// a monochrome App Font glyph following the bar's text
    /// colors. Apps without a resolvable image fall back to the
    /// App Font `Default` glyph either way.
    public var iconSource: BarAppIconSource = .appImage
    public var tabBackground: TabBackground = .boxed
    /// Liquid Glass finish (macOS 26+), orthogonal to the shape —
    /// see `AppBarStyle.liquidGlass`. Ignored below 26.
    public var liquidGlass: Bool = false
    /// Hug by default, like the App Bar (QA 2026-07-19).
    public var tabBackgroundFit: TabBackgroundFit = .hug
    public var activeIndicator: ActiveIndicator = .outline
    /// Corner rounding as a percentage (0–100) of thickness/2,
    /// like the App Bar.
    public var cornerRoundness: CGFloat = 50
    /// Opacity (0.05–1) of everything on an INACTIVE space — the
    /// outer dim tier. Lua-only (`set_dim_factor`, no GUI); default
    /// = `BarAccent.untintedAlpha`.
    public var dimFactor: CGFloat = BarAccent.untintedAlpha
    /// Opacity (0.05–1) of an UNFOCUSED window's glyph on the
    /// ACTIVE space — the middle dim tier. Lua-only
    /// (`set_active_dim_factor`); default =
    /// `BarAccent.activeUnfocusedAlpha`. Independent of `dimFactor`
    /// (Lua may invert the ladder; the GUI is the curated gate).
    public var activeDimFactor: CGFloat =
        BarAccent.activeUnfocusedAlpha
    /// Trailing `| <front app>` segment (spaces.lua's front_app);
    /// off by default (ui-designer verdict 6).
    public var showFrontApp = false
    /// Hides empty spaces except the current one (verdict 4);
    /// off by default.
    public var hideEmpty = false
    /// Sticky/floating state badges on space items (#414):
    /// sticky top-left, floating bottom-left (top-right stays
    /// the group count). On by default and Lua-only
    /// (`set_sticky_badge`, no GUI toggle) — in the bar there
    /// is otherwise no way to tell tiled from floating, and a
    /// sticky window is invisible state. Space Bar only; the
    /// App Bar shows no state badges.
    public var stickyBadge = true
    /// Drag-drop spring dwell (#372): how long a dragged window
    /// must hover a Space item before the visible space springs
    /// to it, in milliseconds. Read through `resolvedSpringDelay`,
    /// which clamps to `springDelayRange`. Default 1500 (1.5 s).
    /// (Named without the `MS` suffix so the reflected field name
    /// snakes to the `spring_delay` key the parity guard expects.)
    public var springDelay = 1500
    /// Inactive spaces: identifier + glyphs (muted tier).
    /// KiwiCanopy theme; defaults mirrored as examples in
    /// docs/lua-reference.md (Space Bar colors) — change both.
    public var itemColor = "#EAF3EE66"
    /// The active space's accent (identifier + its glyphs).
    public var activeItemColor = "#8DB354"
    /// The focused window's accent, on two surfaces: its glyph
    /// inside the active space, and the front-app segment (glyph
    /// + name). Deliberately NOT the group-count badge's text —
    /// that is ink on an independently chosen chip rather than on
    /// the bar plate, so it keeps `groupBadgeTextColor` and lets
    /// the alpha ladder carry focus (#470). A
    /// genuinely different hue, not a tint of the active-space
    /// color, so the two states read apart (QA 2026-07-19).
    ///
    /// Converged onto the palette in #470 by reusing the amber
    /// the rebrand had *already* ratified for the drag drop-zone
    /// (`DragVisual.dropZoneDefault`) rather than inventing a
    /// hue: same H36 as the old `#E8A33D`, dropped L57% → L40%.
    /// The **lightness** is load-bearing, not the hue — hue alone
    /// does not survive colour-vision deficiency against a green
    /// primary. Keep that gap if this is retuned; a lighter amber
    /// loses it (`SpaceBarAccentSeparationTests` pins the floor,
    /// docs/design-decisions.md carries the numbers). Accepted
    /// trade: focused now reads darker than the active green, not
    /// brighter. Default mirrored in docs/lua-reference.md.
    public var focusedItemColor = "#C2790A"
    /// Hover tint on non-active space items.
    public var hoverFillColor = "#AACB5D80"
    public var hoverItemColor = "#EAF3EE"
    /// The fill under the items — a box per Space (Boxed), one
    /// shared plate (Plain), or the Liquid Glass tint (Material).
    /// A translucent cool-dark surface under the kiwi accent.
    public var fillColor = "#14201C66"
    public var highlightColor = "#8DB354"
    /// Count badges (grouped duplicates and the "+n" overflow),
    /// shown in these colors on the active space and muted from
    /// `itemColor` on inactive ones.
    public var groupBadgeColor = "#B00020"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

    /// Liquid Glass paints only where the platform renders it —
    /// false below macOS 26 even if `liquidGlass` is stored true.
    public var glassEnabled: Bool {
        liquidGlass && AppBarStyle.glassAvailable
    }

    /// An item paints its own box: Boxed shape, no glass finish.
    public var hasBox: Bool {
        tabBackground == .boxed && !glassEnabled
    }

}

// MARK: - Codable

/// The conformance is declared here, in the type's own file,
/// because Swift only synthesizes `encode(to:)` where the
/// conformance sits — a cross-file `extension … : Codable` would
/// force a hand-written encode, i.e. exactly the mirrored field
/// list `.claude/rules/parity-tests.md` says to avoid. The keys
/// and the sparse decode live in `SpaceBarStyle+Coding.swift`.
///
/// This is the **opposite** placement from
/// `TilingSettings+Coding.swift`, deliberately, and the two
/// should not be "harmonized": that type hand-writes its encode,
/// so it can keep the conformance next to the implementation and
/// warns against a gutted extension re-synthesizing camelCase.
/// `SpaceBarStyle` relies on synthesis instead, so its
/// conformance has to stay here. The residual hazard — deleting
/// or renaming `CodingKeys` in the other file would let both
/// sides silently re-synthesize camelCase — is backstopped by
/// `SpaceBarParityTests` (which references
/// `CodingKeys.allCases`, so it stops compiling) and
/// `SettingsCodingTests` (which pins the snake_case keys).
extension SpaceBarStyle: Codable {}
