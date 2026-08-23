import CoreGraphics

/// The track weight paths' shared parameter derivation
/// (#933/#944): which gaps and outer pair each axis subtracts,
/// stated ONCE. Split from `TrackLayout+Domain` for file size.
///
/// Three sites divide a weighted track span — the interactive
/// clamps (`resizeTrackWeight` / `resizeTrackShare`) and the
/// retile-time heal (`healTrackSessionWeights`) — and before
/// this file each hand-copied the axis→gap selection beside its
/// own call. That is the exact drift `weightedSpan`'s doc
/// blames for #925, one level up: a future change to track gap
/// accounting that updates the clamps and forgets the heal
/// leaves the heal reasoning over a different span and silently
/// rewriting legal weights on every retile — worse than a
/// drifted clamp, which only refuses a press.
extension TrackLayout {
    /// The gap-adjusted span the per-track head weights divide
    /// ACROSS the axis (columns' widths / rows' heights).
    /// `region` is the raw layout-region dimension on that axis
    /// (the resize dispatch's `span`; `bounds.width` for
    /// vertical tracks).
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

    /// The gap-adjusted span one track's per-window shares
    /// divide ALONG the axis — `acrossSpan`'s orthogonal, with
    /// the gap and outer pairs swapped accordingly.
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

    /// The render's folded partition, assembled ONCE (#944
    /// review round 2): marker tracks counted uncapped, folded
    /// through `overflowCap` to the effective render cap.
    /// Consumed by `calculateGeometry`, the `track.swap` guard,
    /// and the retile-time heal — which hand-mirrored this
    /// assembly at three sites until the round caught the
    /// fourth-copy drift risk (a fold-rule change updating the
    /// render and forgetting the heal re-opens the exact defect
    /// the folded heal fixed). `geoCap` stays a parameter: the
    /// three sites legitimately source their context
    /// differently (the render's full context, the swap guard's
    /// live `layoutInput` with a headless fallback, the heal's
    /// minimal probe), and that split is each site's own doc's
    /// to argue. At a SECOND consumer of the merge question —
    /// "does the fold merge ≥2 marker tracks, not a lone N+1th
    /// slot" (`markers > cap`, today ruled once, in the swap
    /// guard) — promote this tuple to a named struct carrying
    /// that predicate as a member: a tuple cannot, which is why
    /// the guard holds it as a comment (round-4 architect
    /// review).
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

    /// The id a track's weight is keyed under: the first LOCAL
    /// member of the slice. A tiled-sticky traveler heading a
    /// track (#414 v2) is not in `space.windows`, so an entry
    /// under its id could never be pruned (orphan; recycled-id
    /// hazard, #308) — the weight writers key past it, and a
    /// track with NO local member takes no write at all. One
    /// copy for the clamp and the heal, like the spans above.
    public static func localHead(
        ofTrack range: Range<Int>,
        tiled: [WindowID],
        members: [WindowID]
    ) -> WindowID? {
        tiled[range].first { members.contains($0) }
    }
}
