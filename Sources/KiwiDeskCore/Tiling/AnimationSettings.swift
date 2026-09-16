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

    /// The Monocle focus-change card flip (#1391): a blurred
    /// plate turns from the outgoing window's app icon to the
    /// incoming one's while the focus swaps beneath it. Not
    /// under the `anyEnabled` master, like `onScrolling`.
    public var onMonocleFocus = true

    /// The flip's turn in milliseconds (100–1000 ms, #1391); the
    /// blur fades around it on fixed times.
    public var monocleFlipDurationMS = 450 {
        didSet {
            monocleFlipDurationMS = Self.clampFlipMS(
                monocleFlipDurationMS
            )
        }
    }

    /// The band every spring duration clamps to, and the one a
    /// control's edges derive from (gui.md, #1359).
    public static let durationBand = 50...1000
    /// The flip's band: below 100 ms the plate is a flash, not a
    /// turn.
    public static let flipDurationBand = 100...1000

    static func clampMS(_ ms: Int) -> Int {
        min(max(ms, durationBand.lowerBound), durationBand.upperBound)
    }

    static func clampFlipMS(_ ms: Int) -> Int {
        min(
            max(ms, flipDurationBand.lowerBound),
            flipDurationBand.upperBound
        )
    }

    private enum CodingKeys: String, CodingKey {
        case onSpaceChange = "on_space_change"
        case onScrolling = "on_scrolling"
        case onWindowResize = "on_window_resize"
        case onWindowSwap = "on_window_swap"
        case onRelayout = "on_relayout"
        case durationMS = "duration"
        case scrollDurationMS = "scroll_duration"
        case onMonocleFocus = "on_monocle_focus"
        case monocleFlipDurationMS = "monocle_flip_duration"
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
        onMonocleFocus =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .onMonocleFocus
            ) ?? true
        monocleFlipDurationMS = Self.clampFlipMS(
            try container.decodeIfPresent(
                Int.self,
                forKey: .monocleFlipDurationMS
            ) ?? 450
        )
    }
}
