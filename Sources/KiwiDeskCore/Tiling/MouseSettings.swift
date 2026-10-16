import Foundation

/// Mouse pointer interaction settings (#186, #1869).
public struct MouseSettings: Sendable, Equatable, Codable {
    /// Warps pointer to center of newly-focused window (#186).
    /// Off by default, matching i3/sway/yabai.
    public var followsFocus = false
    /// Focuses and raises the window the pointer comes to rest on
    /// (#1869) — the inverse of `followsFocus`. Off by default.
    public var hoverFocus = false
    /// How long the pointer rests before hover focus acts, in
    /// milliseconds (`mouse.hover_focus_delay`, Lua-only, #1869);
    /// never negative.
    public var hoverFocusDelayMS = Self.defaultHoverFocusDelayMS {
        didSet { hoverFocusDelayMS = max(0, hoverFocusDelayMS) }
    }

    private enum CodingKeys: String, CodingKey {
        case followsFocus = "follows_focus"
        case hoverFocus = "hover_focus"
        case hoverFocusDelayMS = "hover_focus_delay"
    }

    /// Longer than the bar peek's dwell: focus and raise redirect
    /// typing where a peek only labels, and 200 ms rides out a
    /// trackpad re-clutch mid-travel (#1869 design read).
    public static let defaultHoverFocusDelayMS = 200

    public init() {}

    /// A profile saved before this key existed (or a
    /// hand-written partial object) keeps the missing default,
    /// matching `TilingSettings`' missing-keys contract.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        followsFocus =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .followsFocus
            ) ?? false
        hoverFocus =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .hoverFocus
            ) ?? false
        hoverFocusDelayMS = max(
            0,
            try container.decodeIfPresent(
                Int.self,
                forKey: .hoverFocusDelayMS
            ) ?? Self.defaultHoverFocusDelayMS
        )
    }
}
