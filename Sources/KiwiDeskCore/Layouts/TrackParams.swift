import Foundation

/// Track layout parameters (#128, #67; partitions via `Space.trackBreaks`).
public struct TrackParams: Sendable, Equatable, Codable {
    public enum Axis: String, Sendable, Codable, CaseIterable {
        case vertical
        case horizontal
    }

    /// Placement policy for newly spawned windows (#128, #437).
    public enum NewWindowTrack: String, Sendable, Codable, CaseIterable {
        case ownTrack = "own_track"
        case focusedTrack = "focused_track"
    }

    public var axis: Axis = .vertical
    /// Dynamic track limit management (#178).
    public var autoTracks = true
    /// Tracks ON SCREEN when `autoTracks` is false, the overflow
    /// track counted (#1354, owner ruling 2026-09-09): the number
    /// a user types is the number they see. 3 by default, the
    /// picture the pre-#1354 default of two normal tracks drew.
    public var limit: Int = 3

    /// The floor (#1354): one track would be the overflow alone,
    /// everything folded, which is no track layout at all. Every
    /// entry point holds it — the setters refuse below it, the
    /// steppers start at it, the crossing lifts a stored 1 to it.
    public static let minLimit = 2

    /// The steppers' ceiling: the old band's ten normal tracks
    /// plus the overflow, so a stored 10 the crossing lifted to
    /// 11 still sits inside the control (#1354). Lua is open
    /// above it; the layout draws what fits either way.
    public static let stepperMaxLimit = 11
    public var newWindow: NewWindowTrack = .focusedTrack
    /// Position of new window within target track.
    public var newWindowPosition: SpawnPlacement = .first
    /// Rendering style for overflow track (#192).
    public var overflowStyle: StackParams.OverflowStyle =
        .cascadeAll
    /// Wraps focus navigation past ends (#168).
    public var wrapFocus = false
    /// Per-space overrides.
    public var override: [SpaceID: TrackOverride] = [:]

    public init() {}

    /// Hard cap on tracks: 0 = unlimited, otherwise the limit
    /// itself — the overflow track is inside it (#192, #1354).
    public var trackCap: Int {
        autoTracks ? 0 : max(Self.minLimit, limit)
    }

    /// Normal track capacity before overflow fold (#192, #198; read by
    /// `TrackLayout.overflowCap`): one below the cap, derived.
    public var normalCap: Int {
        autoTracks ? .max : trackCap - 1
    }

    private enum CodingKeys: String, CodingKey {
        case axis
        case autoTracks = "auto_tracks"
        case limit
        case newWindow = "new_window"
        case newWindowPosition = "new_window_position"
        case overflowStyle = "overflow_style"
        case wrapFocus = "wrap_focus"
        case override
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        axis =
            try container.decodeIfPresent(
                Axis.self,
                forKey: .axis
            ) ?? .vertical
        autoTracks =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .autoTracks
            ) ?? true
        limit =
            try container.decodeIfPresent(
                Int.self,
                forKey: .limit
            ) ?? TrackParams().limit
        newWindow =
            try container.decodeIfPresent(
                NewWindowTrack.self,
                forKey: .newWindow
            ) ?? .focusedTrack
        newWindowPosition =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPosition
            ) ?? .first
        overflowStyle =
            try container.decodeIfPresent(
                StackParams.OverflowStyle.self,
                forKey: .overflowStyle
            ) ?? .cascadeAll
        wrapFocus =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .wrapFocus
            ) ?? false
        override =
            try container.decodeIfPresent(
                [SpaceID: TrackOverride].self,
                forKey: .override
            ) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(axis, forKey: .axis)
        try container.encode(autoTracks, forKey: .autoTracks)
        try container.encode(limit, forKey: .limit)
        try container.encode(newWindow, forKey: .newWindow)
        try container.encode(
            newWindowPosition,
            forKey: .newWindowPosition
        )
        try container.encode(overflowStyle, forKey: .overflowStyle)
        try container.encode(wrapFocus, forKey: .wrapFocus)
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
    }
}
