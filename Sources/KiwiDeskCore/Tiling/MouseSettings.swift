import Foundation

/// Mouse-pointer behaviour toggles (issue #186).
///
/// JSON shape follows the one-vocabulary rule (AGENTS.md §5):
/// `mouse.set_follows_focus` → `mouse.follows_focus`. The
/// singular `mouse` namespace leaves room for a later
/// `focus_follows_mouse` sibling (the inverse behaviour)
/// without renaming.
public struct MouseSettings: Sendable, Equatable, Codable {
    /// Warp the pointer to the center of the newly-focused
    /// window, so the next click, scroll, or hover lands on
    /// the window the keyboard is working in — the standard
    /// companion behaviour in i3/sway/yabai. Off by default,
    /// matching those WMs.
    public var followsFocus = false

    private enum CodingKeys: String, CodingKey {
        case followsFocus = "follows_focus"
    }

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
    }
}
