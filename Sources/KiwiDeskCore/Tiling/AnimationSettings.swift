import Foundation

/// Per-trigger animation configuration and duration settings (#11, #50).
public struct AnimationSettings: Sendable, Equatable, Codable {
    /// Play the plate slide on a Space switch (#1956); off, the
    /// switch is instant. On by default since #1931, and a file
    /// from before turned on once, its whole-written `false` being
    /// no evidence of a choice (`SpaceChangeOnMigrationTests`).
    public var onSpaceChange = true

    /// The plate slide's pace in milliseconds (#1931): the strip's
    /// spring response, its fades scaling with it. The default is
    /// the slide's own timing, so an unset file plays as before.
    public var spaceChangeDurationMS = spaceChangeDefaultMS {
        didSet {
            spaceChangeDurationMS = Self.clampSpaceChangeMS(
                spaceChangeDurationMS
            )
        }
    }

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

    /// The shelf's glide (#1838): a section growing in or out, the
    /// plate and sections re-placing, a group folding — one motion
    /// on one pace. Off, the shelf lands; not under `anyEnabled`.
    public var onShelf = true

    /// The shelf glide in milliseconds (500–2000 ms, #1838).
    public var shelfDurationMS = 750 {
        didSet { shelfDurationMS = Self.clampShelfMS(shelfDurationMS) }
    }

    /// The band every spring duration clamps to, and the one a
    /// control's edges derive from (gui.md, #1359).
    public static let durationBand = 50...1000
    /// The flip's band: below 100 ms the plate is a flash, not a
    /// turn.
    public static let flipDurationBand = 100...1000
    /// The plate slide's default: its own timing (owner,
    /// 2026-10-09, #1931 — the steadiest pace under GPU load, and a
    /// slower one lengthens the blur, not the readable plates).
    /// Moving it moves a stored default and owes profiles.md's
    /// crossing question (#1369).
    public static let spaceChangeDefaultMS = 300
    /// The slide's band: below it the strip is a jump; above it a
    /// switch outlasts the hand that pressed it.
    public static let spaceChangeDurationBand = 150...1000
    /// The shelf glide's band (owner, 2026-09-30): below half a
    /// second it barely reads on a decelerating curve.
    public static let shelfDurationBand = 500...2000

    static func clampMS(_ ms: Int) -> Int {
        min(max(ms, durationBand.lowerBound), durationBand.upperBound)
    }

    static func clampSpaceChangeMS(_ ms: Int) -> Int {
        min(
            max(ms, spaceChangeDurationBand.lowerBound),
            spaceChangeDurationBand.upperBound
        )
    }

    static func clampShelfMS(_ ms: Int) -> Int {
        min(
            max(ms, shelfDurationBand.lowerBound),
            shelfDurationBand.upperBound
        )
    }

    static func clampFlipMS(_ ms: Int) -> Int {
        min(
            max(ms, flipDurationBand.lowerBound),
            flipDurationBand.upperBound
        )
    }

    private enum CodingKeys: String, CodingKey {
        case onSpaceChange = "on_space_change"
        case spaceChangeDurationMS = "space_change_duration"
        case onScrolling = "on_scrolling"
        case onWindowResize = "on_window_resize"
        case onWindowSwap = "on_window_swap"
        case onRelayout = "on_relayout"
        case durationMS = "duration"
        case scrollDurationMS = "scroll_duration"
        case onMonocleFocus = "on_monocle_focus"
        case monocleFlipDurationMS = "monocle_flip_duration"
        case onShelf = "on_shelf"
        case shelfDurationMS = "shelf_duration"
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
            ) ?? true
        spaceChangeDurationMS = Self.clampSpaceChangeMS(
            try container.decodeIfPresent(
                Int.self,
                forKey: .spaceChangeDurationMS
            ) ?? Self.spaceChangeDefaultMS
        )
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
        onShelf =
            try container.decodeIfPresent(Bool.self, forKey: .onShelf)
            ?? true
        shelfDurationMS = Self.clampShelfMS(
            try container.decodeIfPresent(
                Int.self,
                forKey: .shelfDurationMS
            ) ?? 750
        )
    }

    /// The plate slide's timings as a share of the plan's own.
    var spaceSlidePace: Double {
        Double(spaceChangeDurationMS)
            / Double(SpaceSlidePlan.baseResponseMS)
    }

    /// The shelf glide's length in seconds, nothing while it is off.
    public var shelfGlideSeconds: TimeInterval {
        onShelf ? TimeInterval(shelfDurationMS) / 1000 : 0
    }
}
