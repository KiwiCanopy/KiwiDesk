import Foundation

/// Per-trigger animation configuration and duration settings (#11, #50).
public struct AnimationSettings: Sendable, Equatable, Codable {
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

    /// The shelf's expand (#1838): a section growing in or out, the
    /// plate and sections re-placing, a group folding — one motion
    /// on one pace. Off, the shelf lands; not under `anyEnabled`.
    /// Was `on_shelf` (`ConfigMigration`, owner ruling 2026-10-21).
    public var onExpand = true

    /// The bars' peeks (#2563): the hover peek's fade and the
    /// overflow mark's pill growing into its list. Off, both show
    /// and hide at once; not under `anyEnabled`.
    public var onPeek = true

    /// The expand in milliseconds (0, or 500–2000 ms, #1838; 0 snaps,
    /// owner ruling 2026-10-21); was `shelf_duration`.
    public var expandDurationMS = 750 {
        didSet { expandDurationMS = Self.clampExpandMS(expandDurationMS) }
    }

    /// A hidden shelf's reveal in milliseconds (0, or 150–800 ms,
    /// owner rulings 2026-10-21): every `reveal_style` plays inside
    /// it, a retract inside `retractShare` of it; 0 shows and hides
    /// at once.
    public var revealDurationMS = 300 {
        didSet { revealDurationMS = Self.clampRevealMS(revealDurationMS) }
    }

    /// The band every spring duration clamps to, and the one a
    /// control's edges derive from (gui.md, #1359).
    public static let durationBand = 50...1000
    /// The expand's band (owner, 2026-09-30): below half a second
    /// it barely reads on a decelerating curve. 0 lies outside it,
    /// for no motion at all (owner ruling, 2026-10-21); a value
    /// between rises to the band.
    public static let expandDurationBand = 500...2000
    /// The reveal's band and step (owner ruling, 2026-10-21); 0
    /// lies outside it as the expand's does, so no value blinks.
    public static let revealDurationBand = 150...800
    public static let revealDurationStep = 50
    /// A retract's share of the reveal's length (owner ruling,
    /// 2026-10-21): leaving reads quicker than arriving.
    public static let retractShare = 0.8

    static func clampMS(_ ms: Int) -> Int {
        min(max(ms, durationBand.lowerBound), durationBand.upperBound)
    }

    static func clampExpandMS(_ ms: Int) -> Int {
        instantOr(ms, band: expandDurationBand)
    }

    static func clampRevealMS(_ ms: Int) -> Int {
        instantOr(ms, band: revealDurationBand)
    }

    /// `ms` as 0 (instant) or inside `band`: a value between 0 and
    /// the band rises to its floor.
    static func instantOr(_ ms: Int, band: ClosedRange<Int>) -> Int {
        guard ms > 0 else { return 0 }
        return min(max(ms, band.lowerBound), band.upperBound)
    }

    /// A stepper's next value over 0 and `band`: one step down
    /// from the floor lands on 0, and any other value in the gap
    /// rises to the floor — so stepping never blinks.
    public static func stepped(
        _ new: Int,
        from current: Int,
        band: ClosedRange<Int>,
        step: Int
    ) -> Int {
        guard new > 0, new < band.lowerBound else {
            return instantOr(new, band: band)
        }
        return current >= band.lowerBound && new == current - step
            ? 0 : band.lowerBound
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case onScrolling = "on_scrolling"
        case onWindowResize = "on_window_resize"
        case onWindowSwap = "on_window_swap"
        case onRelayout = "on_relayout"
        case durationMS = "duration"
        case scrollDurationMS = "scroll_duration"
        case onExpand = "on_expand"
        case onPeek = "on_peek"
        case expandDurationMS = "expand_duration"
        case revealDurationMS = "reveal_duration"
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
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
        onExpand =
            try container.decodeIfPresent(Bool.self, forKey: .onExpand)
            ?? true
        onPeek =
            try container.decodeIfPresent(Bool.self, forKey: .onPeek)
            ?? true
        expandDurationMS = Self.clampExpandMS(
            try container.decodeIfPresent(
                Int.self,
                forKey: .expandDurationMS
            ) ?? 750
        )
        revealDurationMS = Self.clampRevealMS(
            try container.decodeIfPresent(
                Int.self,
                forKey: .revealDurationMS
            ) ?? 300
        )
    }

    /// The expand's length in seconds, nothing while it is off.
    public var expandSeconds: TimeInterval {
        onExpand ? TimeInterval(expandDurationMS) / 1000 : 0
    }

    /// The reveal's length in seconds.
    public var revealSeconds: TimeInterval {
        TimeInterval(revealDurationMS) / 1000
    }
}

extension AnimationSettings {
    /// `self` with the stored field `key` set to `value`, read
    /// through the config's own decoder — its clamps included — so
    /// a look never sets a value a stored file could not (#2176).
    /// Nil for an unknown key or a value of the wrong type.
    func setting(_ key: String, to value: JSONValue) -> Self? {
        guard CodingKeys(rawValue: key) != nil,
            case .object(var map) = JSONValue(encoding: self)
        else { return nil }
        map[key] = value
        guard let patched = try? JSONEncoder().encode(JSONValue.object(map))
        else { return nil }
        return try? JSONDecoder().decode(Self.self, from: patched)
    }
}
