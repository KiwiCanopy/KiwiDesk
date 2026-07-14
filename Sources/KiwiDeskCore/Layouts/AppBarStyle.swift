import CoreGraphics
import Foundation

/// The app bar's global look, shared by every layout that
/// shows a bar (monocle, scrolling). Stored top-level as
/// `app_bar` in profile JSON, set from Lua via `app_bar.set_*`.
/// A layout may
/// override any of these fields for itself (see `LayoutAppBar`);
/// what isn't overridden inherits from here.
///
/// Two things deliberately live *outside* this type because they
/// are layout-specific, not looks: whether the bar is shown
/// (`LayoutAppBar.enabled`) and the focus/scroll axis
/// (`MonocleParams.orientation` / `ScrollingParams.orientation`).
public struct AppBarStyle: Sendable, Equatable {
    /// Which end of the layout's own axis the bar sits on,
    /// resolved to a concrete `AppBarEdge` against that axis:
    /// `start` = top (horizontal axis) / left (vertical),
    /// `end` = bottom / right. Axis-relative so the bar always
    /// renders where the label says — no per-layout clamp.
    public enum Position: String, Sendable, Codable {
        case start, end
    }

    /// How each tab is backed. Orthogonal to `activeIndicator`:
    /// the background is drawn the same on every tab, the
    /// indicator marks only the active one. An extensible set —
    /// more background treatments can join later.
    public enum TabBackground: String, Sendable, Codable {
        /// A box per tab, honoring `cornerRoundness`
        /// (roundness 0 = square).
        case boxed
        /// No per-tab box; names sit on one shared translucent
        /// strip.
        case plain
    }

    /// How the active tab is marked. Orthogonal to
    /// `tabBackground`: works on any background.
    public enum ActiveIndicator: String, Sendable, Codable {
        /// An outlined border around the active tab.
        case ring
        /// An accent bar on the window-facing edge of the
        /// active tab.
        case edgeMark = "edge_mark"
        /// The active tab's slot is left empty — an empty slot
        /// marks the focused window.
        case gap
    }

    public enum Content: String, Sendable, Codable {
        case icon
        case name
        /// Truncation only ever eats the name; the icon
        /// always survives.
        case iconAndName = "icon_and_name"
    }

    /// Which end of the layout's axis the bar sits on
    /// (`start`/`end`); the concrete edge is derived once from
    /// the layout's orientation in `resolvedBar`.
    public var position: Position = .start
    /// Depth of the reserved strip (pt).
    public var thickness: CGFloat = 32
    public var tabBackground: TabBackground = .boxed
    public var activeIndicator: ActiveIndicator = .ring
    /// Item length along the bar (pt) — every item is the
    /// same size. 0 (default) = a standard length per
    /// `content`: a compact square for icon-only, wider once
    /// text is shown. Clamped at layout time between the icon
    /// square (icons never clip) and a quarter of the bar;
    /// items that overflow anyway scroll instead of shrinking.
    public var itemSize: CGFloat = 0
    /// Spacing between items (pt); 0 = touching.
    public var itemGap: CGFloat = 6
    public var content: Content = .iconAndName
    /// Adjacent windows of the same app collapse into one
    /// item wearing a count badge. Clicking the group
    /// focuses its first member, which expands the group
    /// into individual items; focus leaving the group
    /// collapses it again. Non-adjacent windows of the same
    /// app stay separate items.
    public var groupAdjacentWindows = true
    /// 0 (default) = auto: the text scales with the bar
    /// thickness. Any positive value pins the size.
    public var fontSize: CGFloat = 0
    /// Corner rounding as a percentage (0–100) of the maximum:
    /// 100 = a full capsule (radius = thickness/2), 0 = square.
    /// Resolved to a concrete radius in
    /// `resolvedCornerRadius(forThickness:)`. Percentage, not
    /// pt, so it can't exceed thickness/2 (which rendered tabs
    /// as pointed hexagons) and self-adapts to any thickness.
    public var cornerRoundness: CGFloat = 50
    /// Kiwi theme: cream text in translucent shell-brown
    /// boxes; the active item turns flesh-green while its box
    /// stays brown.
    public var textColor = "#F2EBD9"
    public var boxColor = "#8B5E3C66"
    public var activeTextColor = "#4E9F3D"
    public var activeBoxColor = "#8B5E3C66"
    public var highlightColor = "#4E9F3D"
    /// Hover feedback on clickable (non-active) items: a
    /// lighter, translucent kiwi green, deliberately a shade
    /// off the highlight so hover and active never read as
    /// the same state.
    public var hoverColor = "#6DBF5B80"
    /// Text while hovered; defaults to the normal text color
    /// (the hover tint is translucent, so cream stays
    /// readable through it) — the knob exists for themes
    /// whose hover tint needs darker text.
    public var hoverTextColor = "#F2EBD9"
    public var backgroundColor = "#00000000"
    /// The count badge on grouped items.
    public var groupBadgeColor = "#FF3B30"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

    /// The concrete corner radius (pt) for a tab/strip of the
    /// given cross dimension: `cornerRoundness`% of its half —
    /// 100% is a capsule, 0% square. One resolution site shared
    /// by the item box, the shared strip, the scroll arrows, and
    /// the GUI preview so they can't drift.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }
}

// MARK: - Codable

extension AppBarStyle: Codable {
    /// JSON keys are the Lua setters (`app_bar.set_*`) minus the
    /// `set_` verb — the `app_bar` nesting carries the namespace.
    /// `CaseIterable` is load-bearing: the parity test
    /// (`AppBarParityTests`) reflects over `allCases` to prove
    /// every field has a key — do not drop it as "unused".
    enum CodingKeys: String, CodingKey, CaseIterable {
        case position
        case thickness
        case tabBackground = "tab_background"
        case activeIndicator = "active_indicator"
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case content
        case groupAdjacentWindows = "group_adjacent_windows"
        case fontSize = "font_size"
        case cornerRoundness = "corner_roundness"
        case textColor = "text_color"
        case boxColor = "box_color"
        case activeTextColor = "active_text_color"
        case activeBoxColor = "active_box_color"
        case highlightColor = "highlight_color"
        case hoverColor = "hover_color"
        case hoverTextColor = "hover_text_color"
        case backgroundColor = "background_color"
        case groupBadgeColor = "group_badge_color"
        case groupBadgeTextColor = "group_badge_text_color"
    }

    /// Decodes a string-raw enum, tolerating both a missing key
    /// and a present-but-unrecognized raw (an old vocabulary
    /// token) by falling back to `def`.
    static func lenientChoice<T: RawRepresentable>(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys,
        default def: T
    ) -> T where T.RawValue == String {
        guard
            let raw = try? container.decodeIfPresent(
                String.self,
                forKey: key
            ),
            let value = T(rawValue: raw)
        else { return def }
        return value
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        // A profile written before the vocabulary change carries
        // old tokens (`position:"top"`, `shape` under the old
        // `style` key, …). `decodeIfPresent` only swallows a
        // *missing* key, not a present-but-unknown raw, so decode
        // these enums leniently: an unrecognized value falls back
        // to the default instead of failing the whole profile.
        position = Self.lenientChoice(
            container,
            .position,
            default: defaults.position
        )
        thickness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
        tabBackground = Self.lenientChoice(
            container,
            .tabBackground,
            default: defaults.tabBackground
        )
        activeIndicator = Self.lenientChoice(
            container,
            .activeIndicator,
            default: defaults.activeIndicator
        )
        itemSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .itemSize
            ) ?? defaults.itemSize
        itemGap =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .itemGap
            ) ?? defaults.itemGap
        content =
            try container.decodeIfPresent(
                Content.self,
                forKey: .content
            ) ?? defaults.content
        groupAdjacentWindows =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .groupAdjacentWindows
            ) ?? defaults.groupAdjacentWindows
        try decodeAppearance(from: container)
    }

    private mutating func decodeAppearance(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        fontSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .fontSize
            ) ?? defaults.fontSize
        cornerRoundness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRoundness
            ) ?? defaults.cornerRoundness
        textColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .textColor
            ) ?? defaults.textColor
        boxColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .boxColor
            ) ?? defaults.boxColor
        activeTextColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .activeTextColor
            ) ?? defaults.activeTextColor
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
