import CoreGraphics

/// Layout and scrolling metrics calculations for `SpaceBarOverlay`
/// (#372, #385).
extension SpaceBarOverlay {
    struct RunMetrics {
        /// Per-item frame in viewport-local AX coordinates.
        let itemFrames: [CGRect]
        /// Axis coordinate where front segment begins.
        let frontStart: CGFloat
    }

    /// Scroll direction for whole-bar scrolling (#385).
    enum ScrollArrow {
        case back
        case forward
    }

    /// Calculates item frames and front segment start coordinate.
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

    /// Full run length along axis including gaps and front segment
    /// (QA review).
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

    /// Computes scroll arrow insets and viewport size (#385).
    nonisolated static func scrollViewport(
        axis: CGFloat,
        total: CGFloat,
        gap: CGFloat
    ) -> (inset: CGFloat, viewport: CGFloat) {
        let inset = total > axis ? BarArrowView.zone + gap : 0
        return (inset, max(axis - inset * 2, 0))
    }

    /// Calculates clamped scroll offset keeping active item in view.
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

    /// Calculates shift distance per scroll arrow tick (#385).
    nonisolated static func scrollStep(
        lengths: [CGFloat],
        gap: CGFloat
    ) -> CGFloat {
        guard !lengths.isEmpty else { return 0 }
        let avg = lengths.reduce(0, +) / CGFloat(lengths.count)
        return avg + gap
    }

    /// Evaluates whether point falls inside scroll arrow zones (#385, #409).
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
        guard crossPos >= 0, crossPos <= crossLen,
            axisPos >= 0, axisPos <= trailingAxis
        else { return nil }
        let zone = BarArrowView.zone
        if axisPos < zone { return .back }
        if axisPos > trailingAxis - zone { return .forward }
        return nil
    }
}
