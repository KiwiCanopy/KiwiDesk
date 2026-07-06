import Foundation

/// Per-trigger animation toggles (issue #11), replacing the
/// removed global `enable_animations`. Only position-only
/// triggers are toggleable: an "off" size change would be an
/// instant resize, which slow-AX apps (Electron/WebKit) clamp
/// or drop — so window resize/swap always animate and have no
/// toggle here.
///
/// JSON shape follows the one-vocabulary rule (AGENTS.md §5):
/// Lua `animations.set_on_space_change` -> `animations.on_space_change`.
public struct AnimationSettings: Sendable, Equatable, Codable {
    /// Animate windows flying in from / out to the stash corner
    /// on a KiwiDesk **virtual** space switch. Off by default:
    /// many long-distance animations at once mean one blocking
    /// AX call per window per frame, which stutters on slow
    /// responders. Does not affect the native macOS desktop
    /// slide (that is the OS's own, governed by Reduce Motion).
    public var onSpaceChange = false

    /// Animate the layout sliding as focus moves within a
    /// Scrolling space. On by default — it is a position-only
    /// slide, so it is safe on slow-AX apps.
    public var onScrolling = true

    /// Animate window resizes (split-ratio changes, mouse
    /// resize settle). On by default. The instant path now
    /// re-asserts size via the EUI-bracketed size→position→size
    /// set, so "off" lands reliably on most apps — but a few
    /// grid-snapping apps still clamp an un-animated resize.
    public var onWindowResize = true

    /// Animate window swaps (exchanging two tiles). On by
    /// default; "off" snaps the two windows into place.
    public var onWindowSwap = true

    /// Animate the layout reflow — tiles rearranging when a
    /// window opens or closes, the mode switches, or a gap /
    /// layout parameter changes. On by default; "off" snaps the
    /// whole layout. Named to avoid the `layout_change` event.
    public var onRelayout = true

    private enum CodingKeys: String, CodingKey {
        case onSpaceChange = "on_space_change"
        case onScrolling = "on_scrolling"
        case onWindowResize = "on_window_resize"
        case onWindowSwap = "on_window_swap"
        case onRelayout = "on_relayout"
    }

    public init() {}

    /// A profile saved before one of these keys existed (or a
    /// hand-written partial object) keeps the missing default,
    /// matching `TilingSettings`' missing-keys contract.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        onSpaceChange =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .onSpaceChange
            ) ?? false
        onScrolling =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .onScrolling
            ) ?? true
        onWindowResize =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .onWindowResize
            ) ?? true
        onWindowSwap =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .onWindowSwap
            ) ?? true
        onRelayout =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .onRelayout
            ) ?? true
    }
}
