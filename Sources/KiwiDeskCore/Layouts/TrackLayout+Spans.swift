import CoreGraphics

/// Shared parameter derivations for track layout weight paths
/// (`StackLayout.weightedSpan`, `TrackLayout+Domain`, #925, #933, #944).
extension TrackLayout {
    /// Gap-adjusted span divided across track axis
    /// (`StackLayout.weightedSpan`).
    public static func acrossSpan(
        region: Double,
        gaps: Gaps,
        vertical: Bool,
        count: Int
    ) -> Double {
        StackLayout.weightedSpan(
            region: region,
            outer: Double(
                vertical
                    ? gaps.outer.left + gaps.outer.right
                    : gaps.outer.top + gaps.outer.bottom
            ),
            innerGap: Double(
                vertical
                    ? gaps.inner.horizontal
                    : gaps.inner.vertical
            ),
            count: count
        )
    }

    /// Gap-adjusted span divided along track axis
    /// (`StackLayout.weightedSpan`).
    public static func alongSpan(
        region: Double,
        gaps: Gaps,
        vertical: Bool,
        count: Int
    ) -> Double {
        StackLayout.weightedSpan(
            region: region,
            outer: Double(
                vertical
                    ? gaps.outer.top + gaps.outer.bottom
                    : gaps.outer.left + gaps.outer.right
            ),
            innerGap: Double(
                vertical
                    ? gaps.inner.vertical
                    : gaps.inner.horizontal
            ),
            count: count
        )
    }

    /// The partition the RENDER draws for `tiled` in `context`
    /// (#1488): the fold over the geometric cap, assembled once
    /// for the render, the weight heal and the resize clamp, so
    /// the list the cap reads and the list the fold reads cannot
    /// drift apart — the swap guard folds through
    /// `foldedPartition` on its own cap reading.
    public static func renderPartition(
        of tiled: [WindowID],
        in context: LayoutContext
    ) -> (
        counts: [Int], cap: Int, markers: Int,
        overflowTrack: Int?
    ) {
        foldedPartition(
            of: tiled,
            breaks: context.trackBreaks,
            normalCap: context.track.normalCap,
            geoCap: geometricCap(for: context, of: tiled)
        )
    }

    /// Assembles folded track partition for geometry, the swap
    /// guard and the heal — ONE assembly (#944). At a SECOND
    /// consumer of the merge question ("does the fold merge ≥2
    /// marker tracks"), promote this tuple to a named struct
    /// carrying that predicate (round-4 architect review).
    public static func foldedPartition(
        of tiled: [WindowID],
        breaks: Set<WindowID>,
        normalCap: Int,
        geoCap: Int
    ) -> (
        counts: [Int], cap: Int, markers: Int,
        overflowTrack: Int?
    ) {
        let markers = counts(
            of: tiled,
            breaks: breaks,
            cap: 0
        ).count
        let (cap, overflows) = overflowCap(
            markerCount: markers,
            normalCap: normalCap,
            geoCap: geoCap
        )
        let folded = counts(of: tiled, breaks: breaks, cap: cap)
        return (
            folded,
            cap,
            markers,
            overflows ? folded.count - 1 : nil
        )
    }

    /// Resolves local head window ID for track weight keying (#308, #414).
    public static func localHead(
        ofTrack range: Range<Int>,
        tiled: [WindowID],
        members: [WindowID]
    ) -> WindowID? {
        tiled[range].first { members.contains($0) }
    }
}
