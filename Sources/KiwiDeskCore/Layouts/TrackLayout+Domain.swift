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
}

// MARK: - Track state maintenance (Space)

extension Space {
    /// Inserts a window per the track layout's `new_window`
    /// rule (#128): its own new track right after the focused
    /// window's track, or joining the focused track after the
    /// focused window. `ownTrack` falls back to joining when a
    /// positive `cap` is already reached. `isTiled` supplies
    /// the float knowledge the space itself does not hold — the
    /// partition only spans tiled windows.
    public mutating func insertIntoTrack(
        _ window: WindowID,
        rule: TrackParams.NewWindowTrack,
        cap: Int,
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
            cap: cap
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
        let opensOwn =
            rule == .ownTrack
            && (cap <= 0 || counts.count < cap)
        // Insert after an anchor window: the focused one when
        // joining, the track's last tiled window when opening a
        // track behind it. Both positions land inside/behind
        // the intended track no matter where floating windows
        // sit in the full array.
        let anchor: WindowID
        if opensOwn {
            anchor = tiled[ranges[track].upperBound - 1]
            trackBreaks.insert(window)
        } else {
            anchor =
                focusedIndex.map { tiled[$0] }
                ?? tiled[ranges[track].upperBound - 1]
        }
        insert(window, after: anchor)
    }
}
