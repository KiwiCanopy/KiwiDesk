import CoreGraphics
import Foundation

/// Shared domain rules, break-marker partition, and capacity for Track
/// layout (#128).
extension TrackLayout {
    /// Shared weight domain with stack layout (#67).
    public static let weightFloor = StackLayout.weightFloor
    public static let weightRange = StackLayout.weightRange

    /// Partition of tiled windows into tracks via break markers
    /// (`Space.trackBreaks`).
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

    /// Geometric capacity of tracks fitting across `crossSpan` (#192).
    public static func fitCap(
        crossSpan: CGFloat,
        minSize: CGFloat,
        gap: CGFloat
    ) -> Int {
        guard minSize > 0 else { return .max }
        guard crossSpan > 0 else { return 0 }
        return Int((crossSpan + gap) / (minSize + gap))
    }

    /// Index ranges carved out by track counts.
    public static func ranges(of counts: [Int]) -> [Range<Int>] {
        var start = 0
        return counts.map { count in
            defer { start += count }
            return start..<(start + count)
        }
    }

    /// Track index containing the window at `index`.
    public static func trackIndex(
        ofWindowIndex index: Int,
        counts: [Int]
    ) -> Int? {
        ranges(of: counts).firstIndex { $0.contains(index) }
    }

    /// Track size weight from head window in `Space.trackWeights`.
    public static func weight(
        ofTrack range: Range<Int>,
        tiled: [WindowID],
        weights: [WindowID: Double]
    ) -> Double {
        max(weights[tiled[range.lowerBound]] ?? 1, weightFloor)
    }

    /// Number of tracks physically fitting in context (#192, #198).
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

    /// In-track capacity for windows stacked in one track (#437).
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

    /// Break-marker seed for fill-then-spill packing (#437).
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

    /// Whether next window into focused track opens a new track
    /// (#437, #708, #702).
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

    /// Resolves effective render cap and overflow status (#192, #198).
    public static func overflowCap(
        markerCount: Int,
        normalCap: Int,
        geoCap: Int
    ) -> (effectiveCap: Int, overflows: Bool) {
        let overflows =
            markerCount > normalCap || markerCount > geoCap
        guard overflows else { return (markerCount, false) }
        let cap = min(
            normalCap == .max ? geoCap : normalCap + 1,
            geoCap
        )
        return (cap, true)
    }

    /// Whether swap must be refused due to folded overflow track
    /// (#198, #182, #944).
    public static func overflowSwapBlocked(
        tiled: [WindowID],
        breaks: Set<WindowID>,
        windowIndex: Int,
        delta: Int,
        normalCap: Int,
        geoCap: Int
    ) -> Bool {
        let partition = foldedPartition(
            of: tiled,
            breaks: breaks,
            normalCap: normalCap,
            geoCap: geoCap
        )
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
