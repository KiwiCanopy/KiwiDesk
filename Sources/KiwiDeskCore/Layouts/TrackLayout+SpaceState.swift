import CoreGraphics
import Foundation

/// Track state mutations for `Space` (#128, `TrackLayout+Domain`).
extension Space {
    /// What a departing window's break was (#1387): the live set
    /// cannot tell a break `handTrackBreakToSuccessor` gave from
    /// one of the window's own, and the return must.
    public enum BreakProvenance: Sendable, Equatable {
        /// No break: a member of some head's track.
        case member
        /// Headed a track by its own break: the return re-inserts
        /// it and takes a handed one back.
        case head
        /// Holds a break `handTrackBreakToSuccessor` gave it.
        case handed
    }

    /// The member `handTrackBreakToSuccessor(of:)` hands `window`'s
    /// break to: its array successor, when `window` has a break and
    /// the successor has none. The one copy of that decision — the
    /// departure record reads it ahead of the removal (#1387).
    func handOffTarget(of window: WindowID) -> WindowID? {
        guard trackBreaks.contains(window),
            let index = windows.firstIndex(of: window),
            index + 1 < windows.count
        else { return nil }
        let successor = windows[index + 1]
        return trackBreaks.contains(successor) ? nil : successor
    }

    /// Hands window's break marker and weight to its array successor (#128).
    mutating func handTrackBreakToSuccessor(
        of window: WindowID
    ) {
        let successor = handOffTarget(of: window)
        guard trackBreaks.remove(window) != nil else { return }
        // Clear the departing head's weight FIRST, so a head at
        // the array's end (no successor) cannot leave a stale
        // weight a later edge-open would resurrect (review).
        let weight = trackWeights.removeValue(forKey: window)
        guard let successor else { return }
        trackBreaks.insert(successor)
        trackWeights[successor] = weight
    }

    /// The inverse of `handTrackBreakToSuccessor` for a returning
    /// window (#1387): a recorded HEAD takes its break back, and
    /// with it the weight the hand-off moved, from the first
    /// successor HOLDING a break — taken only where the record says
    /// handed, and returned so the caller can end that record. A
    /// holder recorded otherwise, or never recorded, is a head of
    /// its own and stops the walk. Members holding none are walked
    /// past whatever their record: a chain of departures hands one
    /// break along, and a member back ahead of its head sits
    /// between the two.
    @discardableResult
    mutating func takeTrackBreakBack(
        for window: WindowID,
        recorded: (WindowID) -> BreakProvenance?
    ) -> WindowID? {
        guard recorded(window) == .head else { return nil }
        trackBreaks.insert(window)
        guard let index = windows.firstIndex(of: window) else {
            return nil
        }
        for successor in windows[(index + 1)...]
        where trackBreaks.contains(successor) {
            guard recorded(successor) == .handed else { return nil }
            trackBreaks.remove(successor)
            if let weight = trackWeights.removeValue(forKey: successor) {
                trackWeights[window] = weight
            }
            return successor
        }
        return nil
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
