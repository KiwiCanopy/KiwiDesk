import Foundation

/// Per-space overrides of `TrackParams` (#128). Every field is
/// an *optional* mirror of the global track params: nil inherits
/// the global value, a value overrides just that field for one
/// space. Stored sparsely under `layout.track.override[space_id]`
/// and resolved with `resolved(onto:)` — the same optional-mirror
/// shape as `StackOverride`.
///
/// Mirror-parity is guarded by a reflection-based test
/// (`TrackOverrideTests`) per AGENTS.md §5. `newWindow` and
/// `wrapFocus` are excluded by design: both are per-layout
/// behavior, not per-space geometry (the `ScrollingOverride`
/// precedent for `wrapFocus`).
public struct TrackOverride: Sendable, Equatable {
    public var axis: TrackParams.Axis?
    public var count: Int?
    public var overflowStyle: StackParams.OverflowStyle?

    public init() {}

    /// `global` (the layout's own params) with every non-nil
    /// override applied on top, per field.
    public func resolved(onto global: TrackParams) -> TrackParams {
        var out = global
        if let axis { out.axis = axis }
        if let count { out.count = count }
        if let overflowStyle { out.overflowStyle = overflowStyle }
        // Merged params hold no override map (see ScrollingOverride).
        out.override = [:]
        return out
    }

    /// True when no field is set — a fully-inherited space needs
    /// no stored override (drives sparse encoding).
    public var isEmpty: Bool {
        axis == nil && count == nil && overflowStyle == nil
    }
}

// MARK: - Codable

extension TrackOverride: Codable {
    /// Same JSON spelling as the `TrackParams` fields (the
    /// `track.set_*` setters). Only set overrides are written;
    /// inherited fields stay absent.
    enum CodingKeys: String, CodingKey {
        case axis
        case count
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
        count = try container.decodeIfPresent(
            Int.self,
            forKey: .count
        )
        overflowStyle = try container.decodeIfPresent(
            StackParams.OverflowStyle.self,
            forKey: .overflowStyle
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(axis, forKey: .axis)
        try container.encodeIfPresent(count, forKey: .count)
        try container.encodeIfPresent(
            overflowStyle,
            forKey: .overflowStyle
        )
    }
}
