import CoreGraphics

/// How a shelf section shows what it cannot fit (#1517): no
/// arrows — the content fades on each hidden side. The ONE home of
/// the overflow arithmetic both sections read, pure so it is
/// unit-testable (`ShelfOverflowTests`).
public enum ShelfOverflow {
    /// The fade's length per point of shelf thickness, its bounds
    /// (pt), and its share of a section's visible length it may
    /// never exceed, so a short section keeps most of its content
    /// legible. Owner 2026-09-25: the fade starts further in.
    public static let fadePerThickness: CGFloat = 3
    public static let fadeRange: ClosedRange<CGFloat> = 40...96
    public static let fadeShareCap: CGFloat = 0.3

    /// One side's fade length: `fadePerThickness` × thickness,
    /// clamped to
    /// `fadeRange`, capped at `fadeShareCap` of `visible`. With no
    /// `visible` it is the uncapped length — the worst case a
    /// floor must budget for.
    public static func fadeLength(
        thickness: CGFloat,
        visible: CGFloat? = nil
    ) -> CGFloat {
        let scaled = min(
            max(fadePerThickness * thickness, fadeRange.lowerBound),
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

    /// How far from a viewport edge a followed item is kept: past
    /// the fade that side may draw, so the active Space or focused
    /// window never lands half-transparent under it.
    public static func followMargin(
        gap: CGFloat,
        depth: CGFloat,
        viewport: CGFloat
    ) -> CGFloat {
        gap + fadeLength(thickness: depth, visible: viewport)
    }

    /// How far an entry may overhang the viewport and still read
    /// as whole — a sub-point overhang is rounding, not content.
    public static let clipTolerance: CGFloat = 1

    /// How many entries are not wholly visible before and after
    /// the viewport at `offset`: any entry cut by the edge counts,
    /// so a side that clips an entry always fades and says so,
    /// while a sub-point overhang counts for nothing.
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
            if cursor < offset - clipTolerance { before += 1 }
            if cursor + length > offset + viewport + clipTolerance {
                after += 1
            }
            cursor += length + gap
        }
        return (before, after)
    }

    /// Where one page back or forward lands — on an entry
    /// boundary, never mid-entry: forward, the first entry not
    /// wholly clear of the far fade becomes the first one clear of
    /// the near fade; back, the mirror. Where less than one entry
    /// would remain before an end, the page goes to that end, so a
    /// paging run never stops a sliver short of it. A single entry
    /// wider than the clear view still moves by a view.
    public static func pageTarget(
        from offset: CGFloat,
        lengths: [CGFloat],
        gap: CGFloat,
        viewport: CGFloat,
        fade: CGFloat,
        forward: Bool
    ) -> CGFloat {
        let starts = lengths.indices.map { index in
            lengths[..<index].reduce(0) { $0 + $1 + gap }
        }
        let ends = zip(starts, lengths).map { $0 + $1 }
        let total = ends.last ?? 0
        let last = max(total - viewport, 0)
        let entry = lengths.min() ?? 0
        let clear = max(viewport - 2 * fade, viewport / 2)
        let nudge: CGFloat = 0.5
        var target: CGFloat
        if forward {
            let clearEnd = offset + viewport - fade
            if let index = ends.firstIndex(where: { $0 > clearEnd + nudge }) {
                target = starts[index] - fade
                if target <= offset + nudge { target = offset + clear }
            } else {
                target = last
            }
            if last - target < entry { target = last }
        } else {
            let clearStart = offset + fade
            if let index = starts.lastIndex(where: {
                $0 < clearStart - nudge
            }) {
                target = ends[index] - viewport + fade
                if target >= offset - nudge { target = offset - clear }
            } else {
                target = 0
            }
            if target < entry { target = 0 }
        }
        return min(max(target, 0), last)
    }
    /// How far each end of the viewport fades (#1517): a side
    /// fades while it cuts an entry, and a sub-point overhang draws
    /// no fade and no count.
    public struct Fades: Equatable, Sendable {
        public var leading: CGFloat
        public var trailing: CGFloat
        public var before: Int
        public var after: Int

        public static let none = Fades(
            leading: 0,
            trailing: 0,
            before: 0,
            after: 0
        )

        /// `frame` less its fading ends along the axis.
        public func clear(of frame: CGRect, horizontal: Bool) -> CGRect {
            horizontal
                ? CGRect(
                    x: frame.minX + leading,
                    y: frame.minY,
                    width: max(frame.width - leading - trailing, 0),
                    height: frame.height
                )
                : CGRect(
                    x: frame.minX,
                    y: frame.minY + leading,
                    width: frame.width,
                    height: max(frame.height - leading - trailing, 0)
                )
        }
    }

    /// The viewport's fades at `offset`, from `ShelfOverflow`.
    public static func fades(
        lengths: [CGFloat],
        gap: CGFloat,
        total: CGFloat,
        offset: CGFloat,
        viewport: CGFloat,
        depth: CGFloat
    ) -> Fades {
        guard total > viewport, viewport > 0 else { return .none }
        let hidden = hiddenCounts(
            lengths: lengths,
            gap: gap,
            offset: offset,
            viewport: viewport
        )
        let fade = fadeLength(
            thickness: depth,
            visible: viewport
        )
        return Fades(
            leading: hidden.before > 0 ? fade : 0,
            trailing: hidden.after > 0 ? fade : 0,
            before: hidden.before,
            after: hidden.after
        )
    }

}
