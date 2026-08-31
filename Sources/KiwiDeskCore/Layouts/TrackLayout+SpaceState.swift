import CoreGraphics
import Foundation

/// Track state mutations for `Space` (#128, `TrackLayout+Domain`).
extension Space {
    /// Hands window's break marker and weight to its array successor (#128).
    mutating func handTrackBreakToSuccessor(
        of window: WindowID
    ) {
        guard trackBreaks.remove(window) != nil else { return }
        // Clear the departing head's weight FIRST, so a head at
        // the array's end (no successor) cannot leave a stale
        // weight a later edge-open would resurrect (review).
        let weight = trackWeights.removeValue(forKey: window)
        guard let index = windows.firstIndex(of: window),
            index + 1 < windows.count
        else { return }
        let successor = windows[index + 1]
        if !trackBreaks.contains(successor) {
            trackBreaks.insert(successor)
            trackWeights[successor] = weight
        }
    }

    /// Moves a window into the adjacent track or opens a new edge track
    /// (#128).
    public mutating func moveWindowToTrack(
        _ window: WindowID,
        delta: Int,
        cap: Int,
        isTiled: (WindowID) -> Bool
    ) -> Bool {
        let tiled = windows.filter(isTiled)
        guard let index = tiled.firstIndex(of: window) else {
            return false
        }
        let counts = TrackLayout.counts(
            of: tiled,
            breaks: trackBreaks,
            cap: cap
        )
        let ranges = TrackLayout.ranges(of: counts)
        guard
            let track = TrackLayout.trackIndex(
                ofWindowIndex: index,
                counts: counts
            )
        else { return false }
        let target = track + delta
        if ranges.indices.contains(target) {
            handTrackBreakToSuccessor(of: window)
            let anchor = tiled[ranges[target].upperBound - 1]
            windows.removeAll { $0 == window }
            insert(window, after: anchor)
            return true
        }
        guard counts[track] > 1 else { return false }
        guard cap <= 0 || counts.count < cap else {
            return false
        }
        handTrackBreakToSuccessor(of: window)
        windows.removeAll { $0 == window }
        if delta > 0 {
            windows.append(window)
            trackBreaks.insert(window)
        } else {
            if let first = tiled.first(where: { $0 != window }) {
                trackBreaks.insert(first)
            }
            windows.insert(window, at: 0)
            trackBreaks.insert(window)
        }
        return true
    }

    /// Swaps the focused window's track with an adjacent track (#182).
    public mutating func swapTracks(
        _ window: WindowID,
        delta: Int,
        cap: Int,
        isTiled: (WindowID) -> Bool
    ) -> Bool {
        let tiled = windows.filter(isTiled)
        guard let index = tiled.firstIndex(of: window) else {
            return false
        }
        let counts = TrackLayout.counts(
            of: tiled,
            breaks: trackBreaks,
            cap: cap
        )
        let ranges = TrackLayout.ranges(of: counts)
        guard
            let track = TrackLayout.trackIndex(
                ofWindowIndex: index,
                counts: counts
            )
        else { return false }
        let target = track + delta
        guard ranges.indices.contains(target) else {
            return false
        }
        let lead = ranges[min(track, target)]
        let trail = ranges[max(track, target)]
        // Materialize the implicit index-0 head only when the
        // exchange moves it (review m1).
        if lead.lowerBound == 0 {
            trackBreaks.insert(tiled[0])
        }
        var reordered = Array(tiled[..<lead.lowerBound])
        reordered += tiled[trail]
        reordered += tiled[lead]
        reordered += tiled[trail.upperBound...]
        var next = 0
        for slot in windows.indices
        where isTiled(windows[slot]) {
            windows[slot] = reordered[next]
            next += 1
        }
        return true
    }
}
