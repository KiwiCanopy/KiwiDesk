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
    /// The focused window's accent — its glyph inside the active
    /// space AND the front-app segment (glyph + name). A
    /// genuinely different hue, not a tint of the active-space
    /// color, so the two states read apart (QA 2026-07-19).
    /// Kept amber pending its own convergence pass (separate
    /// semantic from the drag drop-zone) — see issue follow-up.
    public var focusedItemColor = "#E8A33D"
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

extension SpaceBarStyle: Codable {
    /// JSON keys are the Lua setters (`space_bar.set_*`) minus
    /// the `set_` verb. `CaseIterable` is load-bearing: the
    /// parity test (`SpaceBarParityTests`) reflects over
    /// `allCases` to prove every field has a key.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case edge
        case alignment
        case thickness
        case boxSize = "box_size"
        case boxGap = "box_gap"
        case fontSize = "font_size"
        case glyphCap = "glyph_cap"
        case iconSource = "icon_source"
        case tabBackground = "tab_background"
        case liquidGlass = "liquid_glass"
        case tabBackgroundFit = "tab_background_fit"
        case activeIndicator = "active_indicator"
        case cornerRoundness = "corner_roundness"
        case dimFactor = "dim_factor"
        case activeDimFactor = "active_dim_factor"
        case showFrontApp = "show_front_app"
        case hideEmpty = "hide_empty"
        case stickyBadge = "sticky_badge"
        case springDelay = "spring_delay"
        case itemColor = "item_color"
        case activeItemColor = "active_item_color"
        case focusedItemColor = "focused_item_color"
        case hoverFillColor = "hover_fill_color"
        case hoverItemColor = "hover_item_color"
        case fillColor = "fill_color"
        case highlightColor = "highlight_color"
        case groupBadgeColor = "group_badge_color"
        case groupBadgeTextColor = "group_badge_text_color"
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? defaults.enabled
        edge =
            try container.decodeIfPresent(
                AppBarEdge.self,
                forKey: .edge
            ) ?? defaults.edge
        alignment =
            try container.decodeIfPresent(
                Alignment.self,
                forKey: .alignment
            ) ?? defaults.alignment
        thickness = max(
            AppBarStyle.minThickness,
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
        )
        boxSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .boxSize
            ) ?? defaults.boxSize
        boxGap =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .boxGap
            ) ?? defaults.boxGap
        fontSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .fontSize
            ) ?? defaults.fontSize
        glyphCap =
            try container.decodeIfPresent(
                Int.self,
                forKey: .glyphCap
            ) ?? defaults.glyphCap
        iconSource =
            try container.decodeIfPresent(
                BarAppIconSource.self,
                forKey: .iconSource
            ) ?? defaults.iconSource
        tabBackground =
            try container.decodeIfPresent(
                TabBackground.self,
                forKey: .tabBackground
            ) ?? defaults.tabBackground
        liquidGlass =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .liquidGlass
            ) ?? defaults.liquidGlass
        tabBackgroundFit =
            try container.decodeIfPresent(
                TabBackgroundFit.self,
                forKey: .tabBackgroundFit
            ) ?? defaults.tabBackgroundFit
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
        cornerRoundness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRoundness
            ) ?? defaults.cornerRoundness
        dimFactor = AppBarStyle.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .dimFactor
            ) ?? defaults.dimFactor
        )
        activeDimFactor = AppBarStyle.clampDim(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .activeDimFactor
            ) ?? defaults.activeDimFactor
        )
        showFrontApp =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .showFrontApp
            ) ?? defaults.showFrontApp
        hideEmpty =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .hideEmpty
            ) ?? defaults.hideEmpty
        stickyBadge =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .stickyBadge
            ) ?? defaults.stickyBadge
        springDelay =
            try container.decodeIfPresent(
                Int.self,
                forKey: .springDelay
            ) ?? defaults.springDelay
        try decodeColors(from: container)
    }

    private mutating func decodeColors(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        itemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .itemColor
            ) ?? defaults.itemColor
        activeItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeItemColor
            ) ?? defaults.activeItemColor
        focusedItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .focusedItemColor
            ) ?? defaults.focusedItemColor
        hoverFillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverFillColor
            ) ?? defaults.hoverFillColor
        hoverItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverItemColor
            ) ?? defaults.hoverItemColor
        fillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .fillColor
            ) ?? defaults.fillColor
        highlightColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .highlightColor
            ) ?? defaults.highlightColor
        groupBadgeColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .groupBadgeColor
            ) ?? defaults.groupBadgeColor
        groupBadgeTextColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .groupBadgeTextColor
            ) ?? defaults.groupBadgeTextColor
    }
}
