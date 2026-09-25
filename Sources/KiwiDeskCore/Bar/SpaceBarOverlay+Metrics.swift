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
    enum ScrollDirection {
        case back
        case forward
    }

    /// Each item's length along the bar; the layer item's slot
    /// carries its section rule. The one derivation `render` and
    /// `naturalLength` share.
    static func itemLengths(
        _ items: [Item],
        depth: CGFloat,
        gap: CGFloat
    ) -> [CGFloat] {
        let leadsWithLayer = leadsWithLayer(items)
        return items.enumerated().map { index, item in
            let length = SpaceBarItemView.autoLength(
                appCount: item.apps.count,
                overflow: item.overflow,
                depth: depth
            )
            return index == 0 && leadsWithLayer
                ? length + layerDividerExtent(gap: gap)
                : length
        }
    }

    /// The Space run's natural length along the shelf — the
    /// `pad` `contentStart` sets it in from the end it hugs, the
    /// run, and past it the plate's one gap, or the `pad` an
    /// `.end` placement keeps where that is larger: what
    /// `ShelfArrangement` hands this bar before it has to share
    /// (#1517). No front-app segment: it hides while an App Bar
    /// shares the shelf, the one case a need is read.
    static func naturalLength(
        items: [Item],
        depth: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        let lengths = itemLengths(items, depth: depth, gap: gap)
        return runTotal(lengths: lengths, gap: gap, frontExtent: 0)
            + SpaceBarItemView.pad + max(gap, SpaceBarItemView.pad)
    }

    /// The active Space item's length — what the shelf's hard
    /// floor keeps in view (#1517); the longest item where none is
    /// active.
    static func activeExtent(
        items: [Item],
        depth: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        let lengths = itemLengths(items, depth: depth, gap: gap)
        if let index = items.firstIndex(where: \.active) {
            return lengths[index]
        }
        return lengths.max() ?? 0
    }

    /// Calculates item frames and front segment start coordinate.
    nonisolated static func runMetrics(
        lengths: [CGFloat],
        gap: CGFloat,
        frontExtent: CGFloat,
        strip: CGRect,
        viewport: CGFloat,
        horizontal: Bool,
        alignment: KiwiShelf.Alignment,
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

    /// The scroll offset keeping the active item in view, in
    /// this bar's measures — `ShelfOverflow.offset` does the
    /// arithmetic (#1517).
    nonisolated static func scrollOffset(
        current: CGFloat,
        lengths: [CGFloat],
        gap: CGFloat,
        frontExtent: CGFloat,
        activeIndex: Int?,
        viewport: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        ShelfOverflow.offset(
            current: current,
            lengths: lengths,
            gap: gap,
            total: runTotal(
                lengths: lengths,
                gap: gap,
                frontExtent: frontExtent
            ),
            activeIndex: activeIndex,
            viewport: viewport,
            margin: margin
        )
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

    /// Which fading end a point rests on, for the drag
    /// autoscroll (#385, #1517): nil in the clear view, where the
    /// items are drop targets instead.
    nonisolated static func fadeHit(
        at local: CGPoint,
        strip: CGRect,
        fades: ShelfOverflow.Fades,
        trailingAxis: CGFloat,
        horizontal: Bool
    ) -> ScrollDirection? {
        let axisPos = horizontal ? local.x : local.y
        let crossPos = horizontal ? local.y : local.x
        let crossLen = horizontal ? strip.height : strip.width
        guard crossPos >= 0, crossPos <= crossLen,
            axisPos >= 0, axisPos <= trailingAxis
        else { return nil }
        if fades.leading > 0, axisPos < fades.leading { return .back }
        if fades.trailing > 0, axisPos > trailingAxis - fades.trailing {
            return .forward
        }
        return nil
    }
}
