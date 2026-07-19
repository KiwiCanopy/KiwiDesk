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
/// The two-accent model is the bar's signature: `textColor`
/// paints inactive spaces, `activeTextColor` the active space's
/// identifier and glyphs, and `focusedItemColor` the focused
/// window's glyph inside the active space (spaces.lua's
/// `space_focused_window`).
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
    /// Hug by default, like the App Bar (QA 2026-07-19).
    public var tabBackgroundFit: TabBackgroundFit = .hug
    public var activeIndicator: ActiveIndicator = .ring
    /// Corner rounding as a percentage (0–100) of thickness/2,
    /// like the App Bar.
    public var cornerRoundness: CGFloat = 50
    /// Trailing `| <front app>` segment (spaces.lua's front_app);
    /// off by default (ui-designer verdict 6).
    public var showFrontApp = false
    /// Hides empty spaces except the current one (verdict 4);
    /// off by default.
    public var hideEmpty = false
    /// Drag-drop spring dwell (#372): how long a dragged window
    /// must hover a Space item before the visible space springs
    /// to it, in milliseconds. Read through `resolvedSpringDelay`,
    /// which clamps to `springDelayRange`. Default 1500 (1.5 s).
    /// (Named without the `MS` suffix so the reflected field name
    /// snakes to the `spring_delay` key the parity guard expects.)
    public var springDelay = 1500
    /// Inactive spaces: identifier + glyphs (muted tier).
    public var textColor = "#F2EBD966"
    /// The active space's accent (identifier + its glyphs).
    public var activeTextColor = "#4E9F3D"
    /// The focused window's glyph inside the active space — the
    /// second accent. A genuinely different hue, not a tint of
    /// the active color: a lighter green washed into the
    /// active-space green and the two states read as one
    /// (QA 2026-07-19).
    public var focusedItemColor = "#E8A33D"
    /// Hover tint on non-active space items.
    public var hoverColor = "#6DBF5B80"
    public var hoverTextColor = "#F2EBD9"
    public var boxColor = "#8B5E3C66"
    public var activeBoxColor = "#8B5E3C66"
    public var highlightColor = "#4E9F3D"
    public var backgroundColor = "#00000000"
    /// Count badges (grouped duplicates and the "+n" overflow),
    /// shown in these colors on the active space and muted from
    /// `textColor` on inactive ones.
    public var groupBadgeColor = "#FF3B30"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

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
        case tabBackgroundFit = "tab_background_fit"
        case activeIndicator = "active_indicator"
        case cornerRoundness = "corner_roundness"
        case showFrontApp = "show_front_app"
        case hideEmpty = "hide_empty"
        case springDelay = "spring_delay"
        case textColor = "text_color"
        case activeTextColor = "active_text_color"
        case focusedItemColor = "focused_item_color"
        case hoverColor = "hover_color"
        case hoverTextColor = "hover_text_color"
        case boxColor = "box_color"
        case activeBoxColor = "active_box_color"
        case highlightColor = "highlight_color"
        case backgroundColor = "background_color"
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
        thickness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
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
        textColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .textColor
            ) ?? defaults.textColor
        activeTextColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeTextColor
            ) ?? defaults.activeTextColor
        focusedItemColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .focusedItemColor
            ) ?? defaults.focusedItemColor
        hoverColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverColor
            ) ?? defaults.hoverColor
        hoverTextColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .hoverTextColor
            ) ?? defaults.hoverTextColor
        boxColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .boxColor
            ) ?? defaults.boxColor
        activeBoxColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeBoxColor
            ) ?? defaults.activeBoxColor
        highlightColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .highlightColor
            ) ?? defaults.highlightColor
        backgroundColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .backgroundColor
            ) ?? defaults.backgroundColor
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
