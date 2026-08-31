import Foundation

/// Per-space overrides of TrackParams: optional mirror, nil
/// inherits (`TrackOverrideTests`, #128). `newWindow`,
/// `newWindowPosition` and `wrapFocus` are excluded by design —
/// per-layout behavior, not per-space geometry.
public struct TrackOverride: Sendable, Equatable {
    public var axis: TrackParams.Axis?
    public var autoTracks: Bool?
    public var limit: Int?
    public var overflowStyle: StackParams.OverflowStyle?

    public init() {}

    /// Merges overrides onto global TrackParams.
    public func resolved(onto global: TrackParams) -> TrackParams {
        var out = global
        if let axis { out.axis = axis }
        if let autoTracks { out.autoTracks = autoTracks }
        if let limit { out.limit = limit }
        if let overflowStyle { out.overflowStyle = overflowStyle }
        // Merged params hold no override map (see
        // ScrollingOverride).
        out.override = [:]
        return out
    }

    /// True when no field is set (drives sparse encoding).
    public var isEmpty: Bool {
        axis == nil && autoTracks == nil && limit == nil
            && overflowStyle == nil
    }
}

extension TrackOverride: Codable {
    enum CodingKeys: String, CodingKey {
        case axis
        case autoTracks = "auto_tracks"
        case limit
        case overflowStyle = "overflow_style"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        axis = try container.decodeIfPresent(
            TrackParams.Axis.self,
            forKey: .axis
        )
        autoTracks = try container.decodeIfPresent(
            Bool.self,
            forKey: .autoTracks
        )
        limit = try container.decodeIfPresent(
            Int.self,
            forKey: .limit
        )
        overflowStyle = try container.decodeIfPresent(
            StackParams.OverflowStyle.self,
            forKey: .overflowStyle
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(axis, forKey: .axis)
        try container.encodeIfPresent(
            autoTracks,
            forKey: .autoTracks
        )
        try container.encodeIfPresent(limit, forKey: .limit)
        try container.encodeIfPresent(
            overflowStyle,
            forKey: .overflowStyle
        )
    }
}
