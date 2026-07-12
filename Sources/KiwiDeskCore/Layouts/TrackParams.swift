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

    /// Whether a new window opens its own track or joins the
    /// focused one (#128 design decision 3). Where within that
    /// choice it lands is the orthogonal `newWindowPosition`.
    public enum NewWindowTrack: String, Sendable, Codable {
        /// The window opens its own new track; `newWindowPosition`
        /// places that track among the others. Falls back to
        /// `focusedTrack` when the track cap is reached.
        case ownTrack = "own_track"
        /// The window joins the focused window's track;
        /// `newWindowPosition` places it among that track's
        /// windows.
        case focusedTrack = "focused_track"
    }

    public var axis: Axis = .vertical
    /// Whether the track count is managed automatically (#178):
    /// on (the default), tracks open and collapse as windows come
    /// and go — no cap. Off pins the count to `count`. The
    /// carousel-vs-grid twin of `GridParams.autoSize`. The layout
    /// reads `count` directly for the normal/overflow split
    /// (#192); spawn, navigation, and swap read `trackCap`
    /// (= `count + 1`, the overflow track included).
    public var autoTracks = true
    /// The fixed maximum number of tracks used when `autoTracks`
    /// is off (the remembered magnitude, so toggling auto off
    /// restores it instead of resetting). Ignored while
    /// `autoTracks` is on. The live partition is session state
    /// (`Space.trackBreaks`), like `stackWeights`.
    public var count: Int = 2
    public var newWindow: NewWindowTrack = .ownTrack
    /// Where a new window lands within the `newWindow` choice,
    /// reusing the shared `SpawnPlacement` vocabulary. For
    /// `own_track` it positions the new track among the others
    /// (`first` = leftmost column / topmost row, `last` = the
    /// far edge, `before`/`after_focused` = beside the focused
    /// track); for `focused_track` it positions the window among
    /// that track's windows. `.first` by default so a new window
    /// is never buried in the overflow. Per-layout, not
    /// per-space: excluded from `TrackOverride` like `newWindow`.
    public var newWindowPosition: SpawnPlacement = .first
    /// How the **overflow track** renders (#192): the far-edge
    /// track that collects the surplus when more tracks exist
    /// than fit side by side at `min_window_size`. The same
    /// `cascade_overflow` / `cascade_all` choice as stack, but
    /// track defaults to **`cascade_all`** — its windows stack
    /// from the top as a clean title-bar pile. Applies ONLY to
    /// the overflow track; every normal track's own overflow is
    /// always `cascade_overflow`. Per-space via `TrackOverride`.
    public var overflowStyle: StackParams.OverflowStyle =
        .cascadeAll
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

    /// The hard cap on **marker** tracks that spawn, navigation,
    /// and swap enforce: 0 (unlimited, dynamic) while `autoTracks`
    /// is on, otherwise `count + 1` (#192) — the fixed `count`
    /// **normal** tracks plus the one extra **overflow track**
    /// that catches the surplus. A new `own_track` window past
    /// `count` therefore opens the overflow track rather than
    /// joining an existing one. The layout reads `count` directly
    /// for the normal/overflow split; everything that moves
    /// windows between tracks reads this so none can disagree on
    /// where the last track is.
    public var trackCap: Int {
        autoTracks ? 0 : max(1, count) + 1
    }

    /// JSON keys follow the Lua setters (`track.set_axis`).
    private enum CodingKeys: String, CodingKey {
        case axis
        case autoTracks = "auto_tracks"
        case count
        case newWindow = "new_window"
        case newWindowPosition = "new_window_position"
        case overflowStyle = "overflow_style"
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
        autoTracks =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .autoTracks
            ) ?? true
        count =
            try container.decodeIfPresent(
                Int.self,
                forKey: .count
            ) ?? 2
        newWindow =
            try container.decodeIfPresent(
                NewWindowTrack.self,
                forKey: .newWindow
            ) ?? .ownTrack
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

    /// Manual encode so the per-space override map stays sparse
    /// (absent when empty), unlike the synthesized encode.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(axis, forKey: .axis)
        try container.encode(autoTracks, forKey: .autoTracks)
        try container.encode(count, forKey: .count)
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
