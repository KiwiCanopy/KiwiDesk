import CoreGraphics
import Foundation

/// The monocle indicator bar's settings, nested under
/// `monocle.bar` in profile JSON (usually spelled
/// `MonocleParams.Bar` at call sites).
public struct MonocleBarParams: Sendable, Equatable {
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

    /// The bar is the point of the monocle overhaul: on by
    /// default, users opt out explicitly.
    public var enabled = true
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
}

// MARK: - Codable

extension MonocleBarParams: Codable {
    /// JSON keys are the Lua setters (`monocle.set_bar_*`)
    /// minus the `bar_` prefix — the nesting carries it.
    private enum CodingKeys: String, CodingKey {
        case enabled
        case position
        case thickness
        case style
        case activeStyle = "active_style"
        case itemSize = "item_size"
        case itemGap = "item_gap"
        case content
        case groupAdjacentWindows = "group_adjacent_windows"
        case groupBadgeColor = "group_badge_color"
        case groupBadgeTextColor = "group_badge_text_color"
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
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        try decodeBehavior(from: container)
        try decodeAppearance(from: container)
    }

    private mutating func decodeBehavior(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? defaults.enabled
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
    }

    private mutating func decodeAppearance(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        let defaults = Self()
        itemGap =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .itemGap
            ) ?? defaults.itemGap
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
