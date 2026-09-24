import CoreGraphics

/// How a shelf section shows what it cannot fit (#1517): no
/// arrows — the content fades on each hidden side. The ONE home of
/// the overflow arithmetic both sections and the Settings preview
/// read, pure so it is unit-testable (`ShelfOverflowTests`).
public enum ShelfOverflow {
    /// The fade's bounds (pt) and its share of a section's visible
    /// length it may never exceed, so a short section keeps most
    /// of its content legible.
    public static let fadeRange: ClosedRange<CGFloat> = 32...72
    public static let fadeShareCap: CGFloat = 0.25

    /// One side's fade length: twice the thickness, clamped to
    /// `fadeRange`, capped at `fadeShareCap` of `visible`. With no
    /// `visible` it is the uncapped length — the worst case a
    /// floor must budget for.
    public static func fadeLength(
        thickness: CGFloat,
        visible: CGFloat? = nil
    ) -> CGFloat {
        let scaled = min(
            max(2 * thickness, fadeRange.lowerBound),
            fadeRange.upperBound
        )
        guard let visible else { return scaled }
        return min(scaled, max(visible, 0) * fadeShareCap)
    }

    /// A section's scroll offset along its run: `current`, moved
    /// just enough to keep the active item `margin` clear of both
    /// viewport edges, clamped to the run. `lengths` are the
    /// items in order, `total` the whole run (a trailing segment
    /// included), both in points.
    public static func offset(
        current: CGFloat,
        lengths: [CGFloat],
        gap: CGFloat,
        total: CGFloat,
        activeIndex: Int?,
        viewport: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        guard total > viewport, viewport > 0 else { return 0 }
        var offset = current
        if let index = activeIndex, lengths.indices.contains(index) {
            let lower = lengths[..<index].reduce(0) { $0 + $1 + gap }
            let upper = lower + lengths[index]
            if lower < offset + margin { offset = lower - margin }
            if upper > offset + viewport - margin {
                offset = upper - viewport + margin
            }
        }
        return min(max(offset, 0), total - viewport)
    }

    /// How many items lie hidden before and after the viewport at
    /// `offset` — an item counts once its middle is out of view,
    /// so a half-shown item under a fade is counted, a sliver is
    /// not.
    public static func hiddenCounts(
        lengths: [CGFloat],
        gap: CGFloat,
        offset: CGFloat,
        viewport: CGFloat
    ) -> (before: Int, after: Int) {
        var cursor: CGFloat = 0
        var before = 0
        var after = 0
        for length in lengths {
            let middle = cursor + length / 2
            if middle < offset { before += 1 }
            if middle > offset + viewport { after += 1 }
            cursor += length + gap
        }
        return (before, after)
    }

    /// Where one page back or forward lands: a viewport less the
    /// two fades, so what sat under the far fade arrives in the
    /// clear, clamped to the run.
    public static func pageTarget(
        from offset: CGFloat,
        total: CGFloat,
        viewport: CGFloat,
        fade: CGFloat,
        forward: Bool
    ) -> CGFloat {
        let step = max(viewport - 2 * fade, viewport / 2)
        let target = offset + (forward ? step : -step)
        return min(max(target, 0), max(total - viewport, 0))
    }
}
