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

    /// How many min-size windows fit stacked inside ONE track
    /// along its in-track axis (#437, fill-then-spill): the
    /// orthogonal of `geometricCap` (which caps how many *tracks*
    /// fit across the cross-axis). A vertical track (column)
    /// stacks its windows down `usable.height` with the vertical
    /// inner gap; a horizontal track (row) runs them along
    /// `usable.width`. Independent of the track count — every
    /// track spans the full in-track axis — so it is a stable
    /// per-display capacity. At equal track weights it matches the
    /// count at which `trackFrames` starts piling (both go through
    /// `StackLayout.maxColumnTotal` / `fitCap`), so a spawn spills
    /// about when the render would otherwise cascade — a min-size
    /// heuristic, since a resized (non-uniform) track can diverge by
    /// a window. At least
    /// 1 (a track always holds one window before spilling);
    /// `.max` when there is no minimum.
    public static func trackCapacity(
        for context: LayoutContext
    ) -> Int {
        let vertical = context.track.axis == .vertical
        let gap =
            vertical
            ? context.gaps.inner.vertical
            : context.gaps.inner.horizontal
        let span =
            vertical
            ? context.usable.height : context.usable.width
        let cap = fitCap(
            crossSpan: span,
            minSize: context.minWindowSize,
            gap: gap
        )
        return cap == .max ? .max : max(1, cap)
    }

    /// The break-marker seed that packs a tiled window list into
    /// tracks of `capacity` each (#437): a break every `capacity`
    /// windows, so entering track mode under fill-then-spill lays
    /// the existing windows out as filled tracks — what
    /// window-by-window spawning would have built — instead of one
    /// column each. `capacity <= 0` (no minimum) is one track
    /// holding everything, matching the seed's "no markers" case.
    public static func fillSeed(
        tiled: [WindowID],
        capacity: Int
    ) -> Set<WindowID> {
        guard capacity > 0 else { return [] }
        var breaks: Set<WindowID> = []
        for (index, id) in tiled.enumerated()
        where index % capacity == 0 {
            breaks.insert(id)
        }
        return breaks
    }

    /// Whether the next window into the focused track opens a NEW
    /// track beside it instead of joining — fill-then-spill
    /// (#437). True when the focused track already holds as many
    /// windows as fit at `min_window_size` (`spillCapacity`) AND
    /// another track fits under `trackCap` (0 = unlimited, the
    /// `auto_tracks` case). A nil `spillCapacity` disables the
    /// spill entirely: the explicit-placement path, which must
    /// join-and-pile rather than relocate a traveler.
    ///
    /// Single authority, for the same reason `overflowCap` is one
    /// (#198): `insertIntoTrack` decides a real spawn with it and
    /// the Layout Defaults preview draws its Track schematic from
    /// it (#708). A preview that re-spelled this condition beside
    /// its drawing would be right the day it was written and drift
    /// the day the rule moved — which is the whole of #702.
    public static func spillsToNewTrack(
        focusedTrackCount: Int,
        trackCount: Int,
        spillCapacity: Int?,
        trackCap: Int
    ) -> Bool {
        guard let capacity = spillCapacity else { return false }
        return focusedTrackCount >= capacity
            && (trackCap == 0 || trackCount < trackCap)
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
        // The one fold assembly (`foldedPartition`): a hand
        // copy here made swap refusals divergeable from the
        // render on a fold-rule change (#944 review round 3).
        let partition = foldedPartition(
            of: tiled,
            breaks: breaks,
            normalCap: normalCap,
            geoCap: geoCap
        )
        // A fold of ≥2 marker tracks, not merely an N+1th
        // overflow slot: only a real merge loses marker
        // identity.
        guard let folded = partition.overflowTrack,
            partition.markers > partition.cap
        else { return false }
        guard
            let track = trackIndex(
                ofWindowIndex: windowIndex,
                counts: partition.counts
            )
        else { return false }
        return track == folded || track + delta == folded
    }
}
