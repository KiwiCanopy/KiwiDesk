import AppKit

/// Layout math and slot sizing for `AppBarOverlay`.
extension AppBarOverlay {
    /// Derived slot lengths and viewport measurements along the bar axis.
    struct Metrics {
        let horizontal: Bool
        let slot: CGFloat
        let gap: CGFloat
        /// The last tiled item, where the float break sits (#1826).
        let breakAfter: Int?
        /// Each slot's length, the break's slot widened by it — the
        /// one lengths array a render and its scroll read.
        let lengths: [CGFloat]
        let total: CGFloat
        let inset: CGFloat
        let viewport: CGFloat
        let alignment: AppBarStyle.BarAlignment
    }

    func metrics(
        strip: CGRect,
        count: Int,
        style: AppBarLook,
        items: [Item],
        capAxis: CGFloat? = nil
    ) -> Metrics {
        let horizontal = style.edge.isHorizontal
        let axis = horizontal ? strip.width : strip.height
        let thickness = horizontal ? strip.height : strip.width
        let gap = style.itemGap
        let slot = Self.slot(
            items: items,
            style: style,
            thickness: thickness,
            capAxis: capAxis ?? axis
        )
        let breakAfter = Self.breakAfter(items)
        let lengths = Self.lengths(
            items: items,
            slot: slot,
            style: style,
            thickness: thickness
        )
        let total = Self.runLength(lengths: lengths, gap: gap)
        // No arrow zones: the run fades on a side that hides entries
        // (#1517). An overflowing run keeps the end pad a fitting one
        // has, where its alignment puts it, so crossing into overflow
        // starts the scroll and moves no end (#1830).
        let pads = Self.endPads(gap: gap)
        let overflows = total > axis - pads
        return Metrics(
            horizontal: horizontal,
            slot: slot,
            gap: gap,
            breakAfter: breakAfter,
            lengths: lengths,
            total: total,
            inset: overflows
                ? Self.overflowLead(pads: pads, alignment: style.alignment)
                : 0,
            viewport: max(overflows ? axis - pads : axis, 0),
            alignment: style.alignment
        )
    }

    /// The pad a fitting run leaves beside it — `naturalLength`'s
    /// and an overflowing viewport's one reading (#1830).
    nonisolated static func endPads(gap: CGFloat) -> CGFloat { gap }

    /// Where an overflowing viewport starts: where a run exactly
    /// `pads` short of the axis would.
    nonisolated static func overflowLead(
        pads: CGFloat,
        alignment: AppBarStyle.BarAlignment
    ) -> CGFloat {
        alignedStart(slack: pads, alignment: alignment)
    }

    /// Where a run leaving `slack` along its axis starts, by
    /// alignment — the one reading `frames`, the drop index and the
    /// overflow lead take.
    nonisolated static func alignedStart(
        slack: CGFloat,
        alignment: AppBarStyle.BarAlignment
    ) -> CGFloat {
        switch alignment {
        case .start: return 0
        case .center: return slack / 2
        case .end: return slack
        }
    }

    /// The run's natural length along the shelf — every slot at
    /// its size, gaps between, and the plate's pad on the side
    /// away from the end it hugs (`frames` sets the run flush at
    /// its end, `BarPlate.frame` pads by one gap): what
    /// `ShelfArrangement` hands this bar before it has to share
    /// (#1517).
    @MainActor
    static func naturalLength(
        items: [Item],
        style: AppBarLook,
        thickness: CGFloat,
        capAxis: CGFloat
    ) -> CGFloat {
        let slot = slot(
            items: items,
            style: style,
            thickness: thickness,
            capAxis: capAxis
        )
        let gap = style.itemGap
        let lengths = lengths(
            items: items,
            slot: slot,
            style: style,
            thickness: thickness
        )
        return runLength(lengths: lengths, gap: gap) + endPads(gap: gap)
    }

    /// One slot's length, its quarter cap measured on `capAxis`.
    @MainActor
    static func slot(
        items: [Item],
        style: AppBarLook,
        thickness: CGFloat,
        capAxis: CGFloat
    ) -> CGFloat {
        slotLength(
            contentDepth: style.contentDepth(forDepth: thickness),
            axis: capAxis,
            autoWidth: autoSlotWidth(
                items: items,
                style: style,
                horizontal: style.edge.isHorizontal,
                thickness: thickness
            )
        )
    }

    nonisolated static func runLength(
        lengths: [CGFloat],
        gap: CGFloat
    ) -> CGFloat {
        lengths.reduce(0, +) + gap * CGFloat(max(lengths.count - 1, 0))
    }

    /// Whether item `index` of `count` opens or closes the run —
    /// read by the slot measurement and by `render` for the views'
    /// run flags, so the measured and laid-out ends agree (#1763).
    nonisolated static func runPlace(
        index: Int,
        count: Int
    ) -> (first: Bool, last: Bool) {
        (index == 0, index == count - 1)
    }

    /// Measures automatic slot width across items. Measure
    /// EXACTLY as the item view draws: `.center` alignment alone
    /// widens an NSTextField cell by ~4 pt, so a raw string
    /// measurement truncates exactly the item that defined the
    /// width (QA 2026-07-19, owner 2026-07-20).
    @MainActor
    static func autoSlotWidth(
        items: [Item],
        style: AppBarLook,
        horizontal: Bool,
        thickness: CGFloat
    ) -> CGFloat {
        let depth = style.contentDepth(forDepth: thickness)
        // Vertical circle slots take no end inset (#1763).
        guard horizontal else { return depth }
        let pad = AppBarItemView.contentPadding
        let font = style.shelf.textFont(
            ofSize: style.resolvedFontSize(forDepth: thickness)
        )
        let iconSide = max(depth - pad * 2, 0)
        let measure = NSTextField(labelWithString: "")
        measure.alignment = .center
        measure.font = font
        measure.maximumNumberOfLines = 1
        measure.lineBreakMode = .byTruncatingTail
        return items.enumerated().reduce(0) { widest, entry in
            let (index, item) = entry
            let place = runPlace(index: index, count: items.count)
            let edge = AppBarItemView.endPadding(
                style,
                depth: thickness,
                first: place.first,
                last: place.last
            )
            measure.stringValue = item.text
            let text = ceil(measure.cell?.cellSize.width ?? 0)
            let spacing =
                iconSide > 0 && text > 0 ? pad / 2 : 0
            let badge =
                item.count >= 2 && text > 0
                ? AppBarItemView.badgeSide(contentSide: depth) + pad
                : 0
            let natural =
                iconSide + spacing + text + badge
                + edge.total
            return max(widest, natural)
        }
    }

    /// Shared slot length, floored at the content depth (#1682)
    /// so measurement's icon side equals layout's — the
    /// slot-fits-widest-title invariant leans on it.
    nonisolated static func slotLength(
        contentDepth: CGFloat,
        axis: CGFloat,
        autoWidth: CGFloat
    ) -> CGFloat {
        max(min(autoWidth, axis / 4), contentDepth)
    }

    /// The scroll offset keeping the focused item in view over
    /// equal slots and no break — `ShelfOverflow.offset` does the
    /// arithmetic (#1517).
    nonisolated static func scrollOffset(
        current: CGFloat,
        activeIndex: Int?,
        slot: CGFloat,
        gap: CGFloat,
        count: Int,
        axis: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        scrollOffset(
            current: current,
            activeIndex: activeIndex,
            lengths: Array(repeating: slot, count: max(count, 0)),
            gap: gap,
            axis: axis,
            margin: margin
        )
    }

    /// The scroll offset over a render's own `Metrics.lengths`.
    nonisolated static func scrollOffset(
        current: CGFloat,
        activeIndex: Int?,
        lengths: [CGFloat],
        gap: CGFloat,
        axis: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        ShelfOverflow.offset(
            current: current,
            lengths: lengths,
            gap: gap,
            total: runLength(lengths: lengths, gap: gap),
            activeIndex: activeIndex,
            viewport: axis,
            margin: margin
        )
    }

    /// Computes item frames along the bar axis (#293 QA), in
    /// `itemRun` coordinates: an overflowing run starts at zero and
    /// `ShelfOverflow.runFrame` carries the scroll.
    nonisolated static func frames(
        lengths: [CGFloat],
        in bounds: CGRect,
        gap: CGFloat,
        horizontal: Bool,
        alignment: AppBarStyle.BarAlignment
    ) -> [CGRect] {
        let total =
            lengths.reduce(0, +)
            + gap * CGFloat(max(lengths.count - 1, 0))
        let axis = horizontal ? bounds.width : bounds.height
        var position =
            total > axis
            ? 0 : alignedStart(slack: axis - total, alignment: alignment)
        return lengths.map { length in
            defer { position += length + gap }
            return horizontal
                ? CGRect(
                    x: position,
                    y: 0,
                    width: length,
                    height: bounds.height
                )
                : CGRect(
                    x: 0,
                    y: position,
                    width: bounds.width,
                    height: length
                )
        }
    }
}
