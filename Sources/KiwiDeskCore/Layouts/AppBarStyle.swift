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
    public enum Position: String, Sendable, Codable {
        case top, bottom, left, right

        /// Whether this edge belongs to a horizontal bar
        /// (items in a row) as opposed to a vertical one.
        public var isHorizontalEdge: Bool {
            self == .top || self == .bottom
        }
    }

    public enum Style: String, Sendable, Codable {
        /// Rounded floating badges, `itemGap` apart.
        case pills
        /// One continuous strip divided into slots.
        case segments
        /// Names on a shared translucent box, active item
        /// underlined.
        case underline
    }

    public enum ActiveStyle: String, Sendable, Codable {
        /// Active item gets the accent (ring / edge bar /
        /// underline, depending on `style`).
        case highlight
        /// Active item is not drawn at all — an empty slot
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

    /// Which edge the bar sits on. A layout resolves this
    /// against its own orientation (see `resolvedPosition`);
    /// a mismatch falls back to the orientation's default edge.
    public var position: Position = .top
    /// Depth of the reserved strip (pt).
    public var thickness: CGFloat = 32
    public var style: Style = .pills
    public var activeStyle: ActiveStyle = .highlight
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
    public var cornerRadius: CGFloat = 8
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

    /// The bar's edge resolved against a layout `orientation`:
    /// a horizontal axis keeps top/bottom (default top), a
    /// vertical axis keeps left/right (default left). Keeps a
    /// mismatched setting rather than erroring.
    public func resolvedPosition(
        horizontalAxis: Bool
    ) -> Position {
        if horizontalAxis {
            return position.isHorizontalEdge ? position : .top
        }
        return position.isHorizontalEdge ? .left : position
    }
}

// MARK: - Codable

extension AppBarStyle: Codable {
    /// JSON keys are the Lua setters (`app_bar.set_*`) minus the
    /// `set_` verb — the `app_bar` nesting carries the namespace.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case position
        case thickness
        case style
        case activeStyle = "active_style"
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case content
        case groupAdjacentWindows = "group_adjacent_windows"
        case fontSize = "font_size"
        case cornerRadius = "corner_radius"
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

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        position =
            try container.decodeIfPresent(
                Position.self,
                forKey: .position
            ) ?? defaults.position
        thickness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .thickness
            ) ?? defaults.thickness
        style =
            try container.decodeIfPresent(
                Style.self,
                forKey: .style
            ) ?? defaults.style
        activeStyle =
            try container.decodeIfPresent(
                ActiveStyle.self,
                forKey: .activeStyle
            ) ?? defaults.activeStyle
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
        cornerRadius =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRadius
            ) ?? defaults.cornerRadius
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
