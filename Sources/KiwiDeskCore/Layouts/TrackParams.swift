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
    /// Fixed maximum number of tracks when `autoTracks` is false (R6/#406).
    public var limit: Int = 2
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

    /// Hard cap on tracks (0 = unlimited, otherwise limit + 1 for overflow,
    /// #192).
    public var trackCap: Int {
        autoTracks ? 0 : max(1, limit) + 1
    }

    /// Normal track capacity before overflow fold (#192, #198; read by
    /// `TrackLayout.overflowCap`).
    public var normalCap: Int {
        autoTracks ? .max : max(1, limit)
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
            ) ?? 2
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
