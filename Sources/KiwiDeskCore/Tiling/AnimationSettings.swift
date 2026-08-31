import Foundation

/// Per-trigger animation configuration and duration settings (#11, #50).
public struct AnimationSettings: Sendable, Equatable, Codable {
    /// Animate virtual space switches (off by default for performance).
    public var onSpaceChange = false

    /// Animate scrolling layout viewport shifts.
    public var onScrolling = true

    /// Animate window resizes and split-ratio changes.
    public var onWindowResize = true

    /// Animate window swap transitions.
    public var onWindowSwap = true

    /// Animate layout reflow upon window open/close or mode changes.
    public var onRelayout = true

    /// Spring animation duration in milliseconds (50–1000 ms).
    public var durationMS = 150 {
        didSet { durationMS = Self.clampMS(durationMS) }
    }

    /// Scrolling layout shift duration in milliseconds
    /// (50–1000 ms, #51, #1020, `ConfigMigration`).
    public var scrollDurationMS = 150 {
        didSet {
            scrollDurationMS = Self.clampMS(scrollDurationMS)
        }
    }

    /// Clamps duration within supported range (50–1000 ms).
    static func clampMS(_ ms: Int) -> Int {
        min(max(ms, 50), 1000)
    }

    private enum CodingKeys: String, CodingKey {
        case onSpaceChange = "on_space_change"
        case onScrolling = "on_scrolling"
        case onWindowResize = "on_window_resize"
        case onWindowSwap = "on_window_swap"
        case onRelayout = "on_relayout"
        case durationMS = "duration"
        case scrollDurationMS = "scroll_duration"
    }

    public init() {}

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
        // `didSet` observers don't fire during init, so clamp the
        // decoded values explicitly through the same helper.
        durationMS = Self.clampMS(
            try container.decodeIfPresent(
                Int.self,
                forKey: .durationMS
            ) ?? 150
        )
        scrollDurationMS = Self.clampMS(
            try container.decodeIfPresent(
                Int.self,
                forKey: .scrollDurationMS
            ) ?? 150
        )
    }
}
