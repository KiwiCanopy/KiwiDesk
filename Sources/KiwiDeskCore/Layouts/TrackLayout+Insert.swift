import Foundation

/// Spawn-time insertion into a track space (#128, #188, #437).
extension Space {
    /// Inserts a window per track rules, supporting fill-then-spill
    /// (#128, #188, #192, #437, `WorkspaceManager.add`).
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
        } else if TrackLayout.spillsToNewTrack(
            focusedTrackCount: counts[track],
            trackCount: counts.count,
            spillCapacity: spillCapacity,
            trackCap: trackCap
        ) {
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

    /// Places `window` at tiled boundary slot, respecting floating windows.
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

    /// Opens `window` as its own new track (#188, `moveWindowToTrack`).
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
        if at == 0, let oldFirst = tiled.first {
            trackBreaks.insert(oldFirst)
        }
    }

    /// Joins `window` to focused track, transferring head weight if needed
    /// (#188).
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
