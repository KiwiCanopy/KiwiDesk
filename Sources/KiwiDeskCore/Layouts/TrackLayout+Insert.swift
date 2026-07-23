import Foundation

/// Spawn-time insertion into a track space (#128, #188): where a
/// new window lands per `new_window` (own vs focused track) and
/// `new_window_position` (first / last / before / after focused).
/// Split from `TrackLayout+Domain` for file size (§2). Pure state
/// over the flat array — no geometry; the layout renders overflow.
extension Space {
    /// Inserts a window per the track layout's `new_window` rule
    /// (#128, #437) and `new_window_position` (#188). `ownTrack`
    /// ALWAYS opens its own new track (#192): the overflow track is
    /// a read-time view, so spawn never caps — the far-edge surplus
    /// folds into it when the layout renders. `focusedTrack` is
    /// fill-then-spill: the window joins the focused track (placed
    /// by `position` among its windows) UNTIL that track already
    /// holds `spillCapacity` windows — as many as fit at
    /// `min_window_size` — and another track fits under `trackCap`,
    /// when it opens a NEW track beside the focused one instead
    /// (#437). `spillCapacity == nil` disables the spill so the
    /// window always joins-and-piles — the explicit-placement path
    /// (`move_to_space` travelers), which must not be relocated.
    /// `trackCap` is 0 (unlimited, `auto_tracks`) or the fixed
    /// `count + 1`; at the cap there is no room to spill, so it
    /// piles. `isTiled` supplies the float knowledge the space
    /// itself does not hold — the partition only spans tiled
    /// windows.
    /// `spillCapacity`/`trackCap` default to the no-spill identity
    /// (join-and-pile): production routes through
    /// `WorkspaceManager.add`, which requires both so every spawn
    /// path chooses, but the Space primitive's default keeps
    /// position-only callers simple.
    public mutating func insertIntoTrack(
        _ window: WindowID,
        rule: TrackParams.NewWindowTrack,
        position: SpawnPlacement,
        spillCapacity: Int? = nil,
        trackCap: Int = 0,
        isTiled: (WindowID) -> Bool
    ) {
        guard !windows.contains(window) else { return }
        let tiled = windows.filter(isTiled)
        guard !tiled.isEmpty else {
            windows.append(window)
            trackBreaks.insert(window)
            return
        }
        // The true (uncapped) marker partition: placement is
        // relative to real tracks, and the overflow merge is the
        // layout's job, not spawn's.
        let counts = TrackLayout.counts(
            of: tiled,
            breaks: trackBreaks,
            cap: 0
        )
        let ranges = TrackLayout.ranges(of: counts)
        let focusedIndex = focused.flatMap {
            tiled.firstIndex(of: $0)
        }
        let track =
            focusedIndex.flatMap { index in
                TrackLayout.trackIndex(
                    ofWindowIndex: index,
                    counts: counts
                )
            } ?? counts.count - 1
        if rule == .ownTrack {
            insertOwnTrack(
                window,
                position: position,
                focusedTrack: track,
                tiled: tiled,
                ranges: ranges
            )
        } else if let capacity = spillCapacity,
            counts[track] >= capacity,
            trackCap == 0 || counts.count < trackCap
        {
            // Fill-then-spill (#437): the focused track can't fit
            // another window at min size and another track fits, so
            // open a NEW track immediately after the focused one.
            // Focus follows it (the caller's `focus`), so the next
            // window fills that track and spills again — the
            // recursion needs no special-casing.
            insertOwnTrack(
                window,
                position: .afterFocused,
                focusedTrack: track,
                tiled: tiled,
                ranges: ranges
            )
        } else {
            joinTrack(
                window,
                position: position,
                track: track,
                focusedIndex: focusedIndex,
                tiled: tiled,
                ranges: ranges
            )
        }
    }

    /// Places `window` into the full array at the slot just
    /// before tiled index `at` (0…tiled.count) — anchoring off
    /// the preceding tiled window so interleaved floating
    /// windows don't shift the track partition.
    private mutating func insertAtTiledBoundary(
        _ window: WindowID,
        tiledIndex at: Int,
        tiled: [WindowID]
    ) {
        if at >= tiled.count {
            windows.append(window)
        } else if at == 0 {
            windows.insert(window, at: 0)
        } else {
            insert(window, after: tiled[at - 1])
        }
    }

    /// Opens `window` as its own new track, positioned among the
    /// existing tracks by `position` (#188).
    private mutating func insertOwnTrack(
        _ window: WindowID,
        position: SpawnPlacement,
        focusedTrack track: Int,
        tiled: [WindowID],
        ranges: [Range<Int>]
    ) {
        let at: Int
        switch position {
        case .first: at = 0
        case .last: at = tiled.count
        case .beforeFocused: at = ranges[track].lowerBound
        case .afterFocused: at = ranges[track].upperBound
        }
        insertAtTiledBoundary(window, tiledIndex: at, tiled: tiled)
        trackBreaks.insert(window)
        // A new front track demotes the old first window to
        // mid-array; make its implicit head explicit so it stays
        // a separate track (the `moveWindowToTrack` precedent).
        if at == 0, let oldFirst = tiled.first {
            trackBreaks.insert(oldFirst)
        }
    }

    /// Joins `window` to the focused track, positioned among its
    /// windows by `position` (#188). Taking the head slot
    /// (`first`, or `before_focused` on the head) transfers the
    /// break marker and the track's cross-axis weight to the new
    /// window so the track keeps its size and boundary.
    private mutating func joinTrack(
        _ window: WindowID,
        position: SpawnPlacement,
        track: Int,
        focusedIndex: Int?,
        tiled: [WindowID],
        ranges: [Range<Int>]
    ) {
        let lb = ranges[track].lowerBound
        let ub = ranges[track].upperBound
        let fi = focusedIndex ?? (ub - 1)
        let at: Int
        let becomesHead: Bool
        switch position {
        case .first:
            at = lb
            becomesHead = true
        case .last:
            at = ub
            becomesHead = false
        case .beforeFocused:
            at = fi
            becomesHead = fi == lb
        case .afterFocused:
            at = fi + 1
            becomesHead = false
        }
        guard becomesHead else {
            insertAtTiledBoundary(
                window,
                tiledIndex: at,
                tiled: tiled
            )
            return
        }
        let oldHead = tiled[lb]
        insertAtTiledBoundary(window, tiledIndex: lb, tiled: tiled)
        trackBreaks.remove(oldHead)
        trackBreaks.insert(window)
        if let weight = trackWeights.removeValue(forKey: oldHead) {
            trackWeights[window] = weight
        }
    }
}
