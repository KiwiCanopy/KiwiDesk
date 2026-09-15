import CoreGraphics
import Foundation

/// Track state mutations for `Space` (#128, `TrackLayout+Domain`).
extension Space {
    /// What a member's break is (#1387): the departure record
    /// keeps it for a window no longer in the row.
    public enum BreakProvenance: Sendable, Equatable {
        /// No break: a member of some head's track.
        case member
        /// Heads a track by a break of its own.
        case head
        /// Holds a break a departing head handed it.
        case handed
    }

    public func breakProvenance(of window: WindowID) -> BreakProvenance {
        handedBreaks.contains(window)
            ? .handed
            : trackBreaks.contains(window) ? .head : .member
    }

    /// The member `handTrackBreakToSuccessor(of:)` hands `window`'s
    /// break to: its array successor, when `window` heads by a
    /// break of its OWN and the successor has none. A handed break
    /// is never handed on (owner ruling, #1387). The one copy of
    /// that decision — the departure record reads it ahead of the
    /// removal.
    func handOffTarget(of window: WindowID) -> WindowID? {
        guard breakProvenance(of: window) == .head,
            let index = windows.firstIndex(of: window),
            index + 1 < windows.count
        else { return nil }
        let successor = windows[index + 1]
        return trackBreaks.contains(successor) ? nil : successor
    }

    /// Hands window's break marker and weight to its array
    /// successor (#128) as a break of the successor's OWN — or
    /// drops them where the break was only handed (#1387), so
    /// every writer that removes a member honours the ruling
    /// through this one door. A dropped weight is session state
    /// the head's return does not recover.
    mutating func handTrackBreakToSuccessor(
        of window: WindowID
    ) {
        let successor = handOffTarget(of: window)
        handedBreaks.remove(window)
        guard trackBreaks.remove(window) != nil else { return }
        // Clear the departing head's weight FIRST, so a head at
        // the array's end (no successor) cannot leave a stale
        // weight a later edge-open would resurrect (review).
        let weight = trackWeights.removeValue(forKey: window)
        guard let successor else { return }
        trackBreaks.insert(successor)
        trackWeights[successor] = weight
    }

    /// Marks a break the departure fold recorded as handed
    /// (#1387), beside the record that names its holder; refused
    /// where the member holds none.
    mutating func markHandedBreak(of window: WindowID) {
        guard trackBreaks.contains(window) else { return }
        handedBreaks.insert(window)
    }

    /// The inverse of `handTrackBreakToSuccessor` for a returning
    /// head (#1387): re-inserts its break and takes it back, weight
    /// and all, from `holder` — the member the departure record
    /// named, never a positional guess — where that member still
    /// holds a HANDED one. Returns whether it did.
    @discardableResult
    mutating func takeTrackBreakBack(
        for window: WindowID,
        from holder: WindowID?
    ) -> Bool {
        trackBreaks.insert(window)
        guard let holder, handedBreaks.remove(holder) != nil else {
            return false
        }
        trackBreaks.remove(holder)
        if let weight = trackWeights.removeValue(forKey: holder) {
            trackWeights[window] = weight
        }
        return true
    }

    /// A holder whose head is gone for good keeps the break by
    /// right (#1387).
    mutating func promoteHandedBreak(of window: WindowID) {
        handedBreaks.remove(window)
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
