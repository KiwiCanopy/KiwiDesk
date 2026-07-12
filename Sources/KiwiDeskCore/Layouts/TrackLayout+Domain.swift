import CoreGraphics
import Foundation

/// The track layout's shared domain rules (#128), split from
/// `TrackLayout` for file size (AGENTS.md §2): the break-marker
/// partition and the slice arithmetic consumed by the layout
/// math, the resize/navigate commands, and the state maintenance
/// — single authorities so no two sites can disagree on where a
/// track begins (the stack-domain parity precedent).
extension TrackLayout {
    /// The weight domain is shared with the stack layout (#67):
    /// track weights and in-track window shares use the same
    /// floor, store clamp and min-size cap, so `resize` steps
    /// feel identical across both layouts and the formulas
    /// cannot drift apart.
    public static let weightFloor = StackLayout.weightFloor
    public static let weightRange = StackLayout.weightRange

    /// The authoritative partition of a tiled window list: a
    /// new track starts at index 0 and at every window carrying
    /// a break marker (`Space.trackBreaks`); tracks past a
    /// positive `cap` merge into the last allowed one. Break
    /// markers are keyed by window, so a floating window (not
    /// in `tiled`) simply does not split — no positional state
    /// to reconcile. No markers means one track holding
    /// everything (mode entry seeds every window as its own
    /// track instead).
    public static func counts(
        of tiled: [WindowID],
        breaks: Set<WindowID>,
        cap: Int
    ) -> [Int] {
        guard !tiled.isEmpty else { return [] }
        var counts: [Int] = []
        for (index, id) in tiled.enumerated() {
            if index == 0 || breaks.contains(id) {
                counts.append(1)
            } else {
                counts[counts.count - 1] += 1
            }
        }
        guard cap > 0, counts.count > cap else { return counts }
        var merged = Array(counts[..<cap])
        merged[cap - 1] += counts[cap...].reduce(0, +)
        return merged
    }

    /// How many `minSize` tracks fit across `crossSpan` with
    /// `gap` between them (#192): the read-time geometric cap
    /// that forms the overflow track. `n` tracks need
    /// `n·minSize + (n-1)·gap ≤ crossSpan`, so
    /// `n = ⌊(crossSpan + gap) / (minSize + gap)⌋`. `minSize ≤ 0`
    /// means no floor (unlimited), matching
    /// `StackLayout.maxColumnTotal`; a span too small for even
    /// one track returns 0 (the caller clamps to a single
    /// overflow track, which then degenerates to the whole-space
    /// cascade). Purely geometric — the surplus beyond this many
    /// tracks folds into the last slot via `counts(cap:)`.
    public static func fitCap(
        crossSpan: CGFloat,
        minSize: CGFloat,
        gap: CGFloat
    ) -> Int {
        guard minSize > 0 else { return .max }
        guard crossSpan > 0 else { return 0 }
        return Int((crossSpan + gap) / (minSize + gap))
    }

    /// The consecutive index ranges the counts carve out of the
    /// tiled window list.
    public static func ranges(of counts: [Int]) -> [Range<Int>] {
        var start = 0
        return counts.map { count in
            defer { start += count }
            return start..<(start + count)
        }
    }

    /// Which track holds the window at tiled index `index`, or
    /// nil when the index is outside the partition.
    public static func trackIndex(
        ofWindowIndex index: Int,
        counts: [Int]
    ) -> Int? {
        ranges(of: counts).firstIndex { $0.contains(index) }
    }

    /// A track's size weight: the head window's entry in
    /// `Space.trackWeights` (absent = 1, an even share). The
    /// head is the slice's first window — where `remove` and
    /// `swap` keep the marker and its weight.
    public static func weight(
        ofTrack range: Range<Int>,
        tiled: [WindowID],
        weights: [WindowID: Double]
    ) -> Double {
        max(weights[tiled[range.lowerBound]] ?? 1, weightFloor)
    }

    /// How many tracks physically fit in `context`'s usable
    /// area (#192): the geometric cap that forms the overflow
    /// track, from the cross-axis span, `min_window_size`, and
    /// the inner gap. `max(1, …)` so a span too small for even
    /// one track still yields a single (degenerate) track.
    /// Shared by the layout math and `track.swap`'s guard (#198)
    /// so neither can disagree on when the far-edge slot folds.
    public static func geometricCap(
        for context: LayoutContext
    ) -> Int {
        let vertical = context.track.axis == .vertical
        let gap =
            vertical
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let crossSpan =
            vertical
            ? context.usable.width : context.usable.height
        return max(
            1,
            fitCap(
                crossSpan: crossSpan,
                minSize: context.minWindowSize,
                gap: gap
            )
        )
    }

    /// Resolves the marker-track count against the two caps the
    /// layout applies — `normalCap` (the fixed `count`, or
    /// `.max` when `auto_tracks` is on) and `geoCap` (how many
    /// tracks fit) — into the effective render cap and whether a
    /// far-edge overflow track exists (#192/#198). The cap is
    /// what `counts(cap:)` folds the surplus into; not
    /// overflowing leaves every marker track standing. Single
    /// authority so the layout and the swap guard fold alike.
    public static func overflowCap(
        markerCount: Int,
        normalCap: Int,
        geoCap: Int
    ) -> (effectiveCap: Int, overflows: Bool) {
        let overflows =
            markerCount > normalCap || markerCount > geoCap
        guard overflows else { return (markerCount, false) }
        // Auto on (`normalCap == .max`) caps at the fit count;
        // a fixed limit adds ONE overflow track past it, but
        // never more than fits. `.max + 1` is sidestepped by the
        // branch — it would overflow `Int`.
        let cap = min(
            normalCap == .max ? geoCap : normalCap + 1,
            geoCap
        )
        return (cap, true)
    }

    /// Whether `track.swap` must refuse because the swap would
    /// disturb the folded overflow track (#198). The far-edge
    /// slot folds ≥2 marker tracks — none keeping its marker
    /// identity — whenever `markerCount` exceeds the effective
    /// render cap, under BOTH a fixed limit AND geometric
    /// pressure (`auto_tracks` on, a small display). Exchanging
    /// that slot re-derives a different composition (windows
    /// leak between tracks; #182 review H1), so a swap that
    /// touches it — the focused window's own track or its
    /// target — is rejected. A lone N+1th track folds nothing
    /// and swaps freely, as do two normal tracks while an
    /// overflow exists elsewhere.
    public static func overflowSwapBlocked(
        tiled: [WindowID],
        breaks: Set<WindowID>,
        windowIndex: Int,
        delta: Int,
        normalCap: Int,
        geoCap: Int
    ) -> Bool {
        let markerCount = counts(
            of: tiled,
            breaks: breaks,
            cap: 0
        ).count
        let (cap, overflows) = overflowCap(
            markerCount: markerCount,
            normalCap: normalCap,
            geoCap: geoCap
        )
        guard overflows, markerCount > cap else { return false }
        let merged = counts(of: tiled, breaks: breaks, cap: cap)
        guard
            let track = trackIndex(
                ofWindowIndex: windowIndex,
                counts: merged
            )
        else { return false }
        let folded = merged.count - 1
        return track == folded || track + delta == folded
    }
}

// MARK: - Track state maintenance (Space)

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
