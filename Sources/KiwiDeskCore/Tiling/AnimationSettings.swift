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
    /// The shelf glide's band (owner, 2026-09-30): below half a
    /// second it barely reads on a decelerating curve.
    public static let shelfDurationBand = 500...2000

    static func clampMS(_ ms: Int) -> Int {
        min(max(ms, durationBand.lowerBound), durationBand.upperBound)
    }

    static func clampShelfMS(_ ms: Int) -> Int {
        min(
            max(ms, shelfDurationBand.lowerBound),
            shelfDurationBand.upperBound
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case onScrolling = "on_scrolling"
        case onWindowResize = "on_window_resize"
        case onWindowSwap = "on_window_swap"
        case onRelayout = "on_relayout"
        case durationMS = "duration"
        case scrollDurationMS = "scroll_duration"
        case onShelf = "on_shelf"
        case shelfDurationMS = "shelf_duration"
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

    /// The shelf glide's length in seconds, nothing while it is off.
    public var shelfGlideSeconds: TimeInterval {
        onShelf ? TimeInterval(shelfDurationMS) / 1000 : 0
    }
}

extension AnimationSettings {
    /// `self` with the stored field `key` set to `value`, read
    /// through the config's own decoder — its clamps included — so
    /// a look never sets a value a stored file could not (#2176).
    /// Nil for an unknown key or a value of the wrong type.
    func setting(_ key: String, to value: JSONValue) -> Self? {
        guard CodingKeys(rawValue: key) != nil,
            let data = try? JSONEncoder().encode(self),
            case .object(var map) = try? JSONDecoder().decode(
                JSONValue.self,
                from: data
            )
        else { return nil }
        map[key] = value
        guard let patched = try? JSONEncoder().encode(JSONValue.object(map))
        else { return nil }
        return try? JSONDecoder().decode(Self.self, from: patched)
    }
}
