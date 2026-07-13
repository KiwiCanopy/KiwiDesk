import CoreGraphics
import Foundation

// Track state maintenance on `Space` (#128): the mutating verbs
// that move windows between tracks — break-marker hand-off,
// `moveWindowToTrack`, `swapTracks`. Split from
// `TrackLayout+Domain` (the actor-free rule authority) for file
// size (AGENTS.md §2); the pure partition math stays there, the
// state mutations live here.
extension Space {
    /// Hands `window`'s break marker (and the track weight
    /// riding it) to its array successor — the shared origin
    /// half of removing a window from its track (#128), used by
    /// `remove(_:)` and `moveWindowToTrack`. A successor that
    /// is already a break means the departing head was alone:
    /// the track collapses, which is the point. The successor
    /// is the *array* neighbor; a floating one holds the marker
    /// dormant until it tiles again (accepted edge — the space
    /// holds no float knowledge here).
    mutating func handTrackBreakToSuccessor(
        of window: WindowID
    ) {
        guard trackBreaks.remove(window) != nil else { return }
        // Clear the departing head's weight first, so a head at
        // the array's end (no successor to hand to) can't leave
        // a stale weight that a later edge-open would resurrect
        // (review). The hand-off below re-homes it onto the
        // successor when there is one.
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

    /// Moves a window into the adjacent track (#128): joining
    /// its end when one exists, opening a new edge track
    /// otherwise (keyboard parity with opening tracks by
    /// spawning). `delta` is ±1 across the axis. Returns false
    /// when there is nothing to do: cross-axis edge with the
    /// cap reached, a lone window already forming the edge
    /// track, or an untracked window.
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
            // Join the neighbor track at its end.
            handTrackBreakToSuccessor(of: window)
            let anchor = tiled[ranges[target].upperBound - 1]
            windows.removeAll { $0 == window }
            insert(window, after: anchor)
            return true
        }
        // Past the edge: open a new track there — unless the
        // window already IS the edge track alone (a no-op) or
        // the cap forbids another track.
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
            // The old first window starts the second track now;
            // index 0 is an implicit head, but the explicit
            // marker keeps it a boundary if something lands
            // before it later.
            if let first = tiled.first(where: { $0 != window }) {
                trackBreaks.insert(first)
            }
            windows.insert(window, at: 0)
            trackBreaks.insert(window)
        }
        return true
    }

    /// Swaps the focused window's whole track with the adjacent
    /// one (#182): the two contiguous slices exchange places in
    /// the tiled order. Break markers and track weights are
    /// keyed by window and ride their heads, so both follow the
    /// slices automatically — only an *implicit* head (tiled
    /// index 0 without an explicit marker) is materialized
    /// first, or the track it starts would merge into its new
    /// predecessor after the exchange. Floating windows
    /// interleaved in the full array keep their slots: only the
    /// tiled positions are rewritten (the `moveWindowToTrack`
    /// filter discipline). `delta` is ±1 across the axis, never
    /// wrapping. Returns false when the window is untracked or
    /// no track lies in that direction (a single track has no
    /// neighbor by construction).
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
        // exchange moves it: an untouched track 0 keeps its
        // authored marker set (review m1).
        if lead.lowerBound == 0 {
            trackBreaks.insert(tiled[0])
        }
        // Adjacent slices exchange; everything around them
        // keeps its order.
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
