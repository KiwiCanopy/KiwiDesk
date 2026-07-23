import CoreGraphics

/// Pure geometry of one Space Bar run: where each item sits in the
/// strip and where the trailing front segment starts. Shared by
/// `render()` and the drag-drop hit test (#372) so the highlighted
/// drop target can never disagree with the drawn layout. The run
/// origin is alignment-, scroll-, and front-segment-dependent, so
/// every consumer must derive it from one place. `pad`/`alignment`/
/// `frontExtent`/`scrollOffset` come from the caller (the scalars,
/// already computed on the main actor) so this stays nonisolated
/// and unit-testable.
///
/// Overflow (#385): when the run is longer than the `viewport`
/// (the item area between the two scroll-arrow zones), the origin
/// collapses to `-scrollOffset` and the three alignments read as
/// one — exactly the App Bar's scroll model. The front segment is
/// the tail of the same run, so it scrolls with the items.
extension SpaceBarOverlay {
    struct RunMetrics {
        /// Per-item frame in viewport-local AX coordinates
        /// (origin at the viewport's leading edge, not the
        /// strip's), in the same order as the input `lengths`.
        let itemFrames: [CGRect]
        /// Axis coordinate where the front segment begins — the
        /// post-run cursor, one gap past the last item (matching
        /// the pre-extraction loop's trailing `cursor`).
        let frontStart: CGFloat
    }

    /// One direction of whole-bar scroll (#385).
    enum ScrollArrow {
        case back
        case forward
    }

    nonisolated static func runMetrics(
        lengths: [CGFloat],
        gap: CGFloat,
        frontExtent: CGFloat,
        strip: CGRect,
        viewport: CGFloat,
        horizontal: Bool,
        alignment: SpaceBarStyle.Alignment,
        pad: CGFloat,
        scrollOffset: CGFloat
    ) -> RunMetrics {
        let total = runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: frontExtent
        )
        let cross = horizontal ? strip.height : strip.width
        // Overflowing runs start at the scroll offset and ignore
        // alignment (the three collapse to one while scrolled);
        // runs that fit place per alignment. Mirrors the App Bar.
        var cursor =
            total > viewport
            ? -scrollOffset
            : contentStart(
                total: total,
                axis: viewport,
                alignment: alignment,
                pad: pad
            )
        var frames: [CGRect] = []
        frames.reserveCapacity(lengths.count)
        for length in lengths {
            frames.append(
                horizontal
                    ? CGRect(
                        x: cursor,
                        y: 0,
                        width: length,
                        height: cross
                    )
                    : CGRect(
                        x: 0,
                        y: cursor,
                        width: cross,
                        height: length
                    )
            )
            cursor += length + gap
        }
        return RunMetrics(itemFrames: frames, frontStart: cursor)
    }

    /// The full run length along the axis: every item, the
    /// gaps between them, the gap ahead of the front segment
    /// (`runMetrics`' cursor adds one after the last item), and
    /// the front segment itself. Missing that gap left the hug
    /// plate flush against the front app's trailing end while
    /// the leading end kept its breathing room (QA round 2
    /// review).
    nonisolated static func runTotal(
        lengths: [CGFloat],
        gap: CGFloat,
        frontExtent: CGFloat
    ) -> CGFloat {
        lengths.reduce(0, +)
            + gap * CGFloat(max(lengths.count - 1, 0))
            + (frontExtent > 0 && !lengths.isEmpty ? gap : 0)
            + frontExtent
    }

    /// The arrow-zone inset and the resulting item viewport for a
    /// strip whose run `total` may overflow its `axis` (#385).
    /// While overflowing, both ends reserve one arrow zone plus a
    /// gap, so a half-scrolled item is cut a gap short of the
    /// arrow instead of sliding under it. 0 inset while it fits.
    nonisolated static func scrollViewport(
        axis: CGFloat,
        total: CGFloat,
        gap: CGFloat
    ) -> (inset: CGFloat, viewport: CGFloat) {
        let inset = total > axis ? BarArrowView.zone + gap : 0
        return (inset, max(axis - inset * 2, 0))
    }

    /// The scroll offset for an overflowing bar: starts from
    /// `current` (so manual arrow/auto scrolling sticks) and moves
    /// just far enough to keep the active item fully visible,
    /// `margin` clear of the viewport's ends. Item lengths vary
    /// (auto `box_size`), so the active item's span is summed from
    /// the real lengths rather than a fixed slot pitch. Pass a nil
    /// index to only clamp. 0 while everything fits.
    nonisolated static func scrollOffset(
        current: CGFloat,
        lengths: [CGFloat],
        gap: CGFloat,
        frontExtent: CGFloat,
        activeIndex: Int?,
        viewport: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        let total = runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: frontExtent
        )
        guard total > viewport, viewport > 0 else { return 0 }
        var offset = current
        if let index = activeIndex,
            index >= 0, index < lengths.count
        {
            let lower = lengths[..<index].reduce(0) {
                $0 + $1 + gap
            }
            let upper = lower + lengths[index]
            if lower < offset + margin {
                offset = lower - margin
            }
            if upper > offset + viewport - margin {
                offset = upper - viewport + margin
            }
        }
        return min(max(offset, 0), total - viewport)
    }

    /// The distance one arrow click (or one autoscroll tick)
    /// shifts an overflowing bar. Items vary in length, so a
    /// single "slot pitch" is ill-defined; the average item length
    /// plus a gap is a comfortable, jitter-free nudge (#385).
    nonisolated static func scrollStep(
        lengths: [CGFloat],
        gap: CGFloat
    ) -> CGFloat {
        guard !lengths.isEmpty else { return 0 }
        let avg = lengths.reduce(0, +) / CGFloat(lengths.count)
        return avg + gap
    }

    /// Which scroll arrow (if any) a strip-local point falls in
    /// while the bar overflows (`inset > 0`); nil off the arrows or
    /// while everything fits. Point-based like the item hit test —
    /// the arrow zones are chrome, structurally outside every
    /// item's hit frame, so a drag cursor is over an arrow XOR an
    /// item, never both (#385). The two govern disjoint zones, so
    /// the autoscroll and the drop-spring never contend.
    nonisolated static func arrowHit(
        at local: CGPoint,
        strip: CGRect,
        inset: CGFloat,
        trailingAxis: CGFloat,
        horizontal: Bool
    ) -> ScrollArrow? {
        guard inset > 0 else { return nil }
        let axisPos = horizontal ? local.x : local.y
        let crossPos = horizontal ? local.y : local.x
        let crossLen = horizontal ? strip.height : strip.width
        // The forward zone ends at `trailingAxis` — the Spaces
        // region's trailing edge — not the strip rim, so a point in
        // the pinned front band past it is not a scroll zone (#409).
        guard crossPos >= 0, crossPos <= crossLen,
            axisPos >= 0, axisPos <= trailingAxis
        else { return nil }
        let zone = BarArrowView.zone
        if axisPos < zone { return .back }
        if axisPos > trailingAxis - zone { return .forward }
        return nil
    }
}
