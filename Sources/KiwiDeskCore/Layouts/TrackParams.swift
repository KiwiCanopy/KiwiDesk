import Foundation

/// Track layout tuning (#128): axis, track cap, where a new
/// window's track comes from, and the focus-wrap toggle. In its
/// own file like `GridParams` (file size).
///
/// The track layout is #67's stack model promoted to first
/// class: windows stay in the flat per-space array, and break
/// markers (`Space.trackBreaks`) partition the tiled list into
/// consecutive slices — the tracks. `masterCount` generalized
/// from one number to a partition; never a tree.
public struct TrackParams: Sendable, Equatable, Codable {
    /// Which way a track runs. Vertical tracks are columns
    /// side by side (windows stack vertically inside one);
    /// horizontal tracks are rows (scrolling's axis
    /// precedent).
    public enum Axis: String, Sendable, Codable {
        case vertical
        case horizontal
    }

    /// Where a new window lands (#128 design decision 3).
    public enum NewWindowTrack: String, Sendable, Codable {
        /// The window opens its own new track right after the
        /// focused one (niri/PaperWM feel — the dynamic
        /// default). Falls back to `focusedTrack` when the
        /// track cap is reached.
        case ownTrack = "own_track"
        /// The window joins the focused window's track, right
        /// after the focused window.
        case focusedTrack = "focused_track"
    }

    public var axis: Axis = .vertical
    /// Maximum number of tracks; `0` = dynamic (unlimited).
    /// This is the persistent *rule*; the live partition is
    /// session state (`Space.trackBreaks`), like
    /// `stackWeights`.
    public var count: Int = 0
    /// What happens when the tracks (across the axis) or a
    /// track's windows (along it) can't all hold
    /// `min_window_size`. Reuses the stack's vocabulary
    /// verbatim (#128): `cascade_overflow` (default) keeps the
    /// fitting prefix tiled and cascades only the remainder;
    /// `cascade_all` cascades the whole space. Applies to both
    /// axes.
    public var overflowStyle: StackParams.OverflowStyle =
        .cascadeOverflow
    public var newWindow: NewWindowTrack = .ownTrack
    /// Whether stepping `focus` past an end wraps to the far
    /// end (#168 twin): along the axis it wraps within the
    /// focused track, across it wraps last <-> first track.
    /// OFF by default; `swap` and `move_to_track` never wrap.
    /// Per-layout, not per-space: excluded from
    /// `TrackOverride` like `newWindow`.
    public var wrapFocus = false
    /// Per-space overrides (`layout.track.override[space_id]`),
    /// resolved via `TilingSettings.resolvedTrack(for:)`.
    public var override: [SpaceID: TrackOverride] = [:]

    public init() {}

    /// JSON keys follow the Lua setters (`track.set_axis`).
    private enum CodingKeys: String, CodingKey {
        case axis
        case count
        case overflowStyle = "overflow_style"
        case newWindow = "new_window"
        case wrapFocus = "wrap_focus"
        case override
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        axis =
            try container.decodeIfPresent(
                Axis.self,
                forKey: .axis
            ) ?? .vertical
        count =
            try container.decodeIfPresent(
                Int.self,
                forKey: .count
            ) ?? 0
        overflowStyle =
            try container.decodeIfPresent(
                StackParams.OverflowStyle.self,
                forKey: .overflowStyle
            ) ?? .cascadeOverflow
        newWindow =
            try container.decodeIfPresent(
                NewWindowTrack.self,
                forKey: .newWindow
            ) ?? .ownTrack
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

    /// Manual encode so the per-space override map stays sparse
    /// (absent when empty), unlike the synthesized encode.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(axis, forKey: .axis)
        try container.encode(count, forKey: .count)
        try container.encode(
            overflowStyle,
            forKey: .overflowStyle
        )
        try container.encode(newWindow, forKey: .newWindow)
        try container.encode(wrapFocus, forKey: .wrapFocus)
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
    }
}
