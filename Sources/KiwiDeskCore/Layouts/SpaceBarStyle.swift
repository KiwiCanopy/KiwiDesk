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
    public typealias ActiveIndicator = AppBarStyle.ActiveIndicator

    /// Off by default — the Space Bar is opt-in.
    public var enabled = false
    /// The absolute screen edge the bar occupies. When it
    /// matches the App Bar's edge, the Space Bar is always
    /// screen-facing and the App Bar window-facing (space-first
    /// reservation) — never a conflict.
    public var edge: AppBarEdge = .left
    /// Depth of the reserved strip (pt); aligned with the App
    /// Bar default.
    public var thickness: CGFloat = 32
    /// Item length along the bar (pt); 0 (default) = auto.
    public var boxSize: CGFloat = 0
    /// Spacing between space items (pt).
    public var boxGap: CGFloat = 6
    /// 0 (default) = auto: text scales with the bar thickness.
    public var fontSize: CGFloat = 0
    /// How app glyphs are drawn (#294): the native app image or
    /// a monochrome App Font glyph following the bar's text
    /// colors. Apps without a resolvable image fall back to the
    /// App Font `Default` glyph either way.
    public var iconSource: BarAppIconSource = .appImage
    public var tabBackground: TabBackground = .boxed
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
    /// Inactive spaces: identifier + glyphs (muted tier).
    public var textColor = "#F2EBD966"
    /// The active space's accent (identifier + its glyphs).
    public var activeTextColor = "#4E9F3D"
    /// The focused window's glyph inside the active space — the
    /// second accent; deliberately a shade off the active color
    /// so the two never read as one state.
    public var focusedItemColor = "#6DBF5B"
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

    /// Muted-badge background alpha over `text_color` on
    /// inactive spaces — one derivation shared by the runtime
    /// item view and the Settings preview.
    public static let mutedBadgeAlpha: CGFloat = 0.3
    /// The front-app divider rule's alpha over `text_color`,
    /// shared the same way.
    public static let frontDividerAlpha: CGFloat = 0.4

    public init() {}

    /// Same %-resolve as `AppBarStyle.resolvedCornerRadius` —
    /// small duplicated helper over a shared protocol (§2.4).
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
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
        case thickness
        case boxSize = "box_size"
        case boxGap = "box_gap"
        case fontSize = "font_size"
        case iconSource = "icon_source"
        case tabBackground = "tab_background"
        case activeIndicator = "active_indicator"
        case cornerRoundness = "corner_roundness"
        case showFrontApp = "show_front_app"
        case hideEmpty = "hide_empty"
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
