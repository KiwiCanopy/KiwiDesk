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
    /// `naturalLength` share. `frontFollows` is whether the
    /// front-app segment ends the run (#1763).
    static func itemLengths(
        _ items: [Item],
        depth: CGFloat,
        look: SpaceBarLook,
        frontFollows: Bool
    ) -> [CGFloat] {
        let gap = look.itemGap
        let leadsWithLayer = leadsWithLayer(items)
        let content = look.contentDepth(forDepth: depth)
        let identifierFont = look.shelf.textFont(
            ofSize: look.identifierFontSize(forDepth: depth)
        )
        return items.enumerated().map { index, item in
            let length = SpaceBarItemView.autoLength(
                appCount: item.apps.count,
                discs: item.discs,
                marked: item.marker != nil,
                identifierInk: item.marker == nil
                    ? nil
                    : SpaceBarItemView.identifierInk(
                        item.spaceGlyph,
                        font: identifierFont
                    ),
                collapsed: item.collapse != nil,
                contentDepth: content,
                glyphGap: look.resolvedGlyphGap,
                ends: itemEnds(
                    items,
                    index: index,
                    depth: depth,
                    look: look,
                    frontFollows: frontFollows
                )
            )
            return index == 0 && leadsWithLayer
                ? length + layerDividerExtent(gap: gap)
                : length
        }
    }

    /// Item `index`'s rounded-end insets at its place in the run —
    /// the one reading `itemLengths` and `contentInsets` share.
    static func itemEnds(
        _ items: [Item],
        index: Int,
        depth: CGFloat,
        look: SpaceBarLook,
        frontFollows: Bool
    ) -> ItemEnds {
        let item = items[index]
        let horizontal = look.edge.isHorizontal
        let place = runPlace(
            index: index,
            count: items.count,
            frontFollows: frontFollows
        )
        let badged = SpaceBarItemView.badgesIdentifier(
            collapsed: item.collapse != nil,
            marked: item.marker != nil
        )
        return SpaceBarItemView.ends(
            look: look,
            depth: depth,
            first: place.first,
            last: place.last,
            leadsWithIcon: SpaceBarItemView.leadsWithIcon(
                item.spaceGlyph,
                badged: badged,
                horizontal: horizontal
            ),
            endsInIcon: SpaceBarItemView.endsInIcon(
                appCount: item.apps.count,
                badged: badged,
                horizontal: horizontal
            ),
            lone: SpaceBarItemView.lone(
                item.spaceGlyph,
                appCount: item.apps.count,
                badged: badged
            )
        )
    }

    /// Whether item `index` of `count` opens or closes the run —
    /// read by `itemLengths` and by `render` for the views' run
    /// flags, so the measured and laid-out ends agree (#1763).
    nonisolated static func runPlace(
        index: Int,
        count: Int,
        frontFollows: Bool
    ) -> (first: Bool, last: Bool) {
        (index == 0, index == count - 1 && !frontFollows)
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
        look: SpaceBarLook
    ) -> CGFloat {
        let gap = look.itemGap
        let lengths = itemLengths(
            items,
            depth: depth,
            look: look,
            frontFollows: false
        )
        return runTotal(lengths: lengths, gap: gap, frontExtent: 0)
            + endPads(gap: gap)
    }

    /// The pads a fitting run leaves beside it — `pad` at the end
    /// it hugs, `max(gap, pad)` at the other: `naturalLength`'s,
    /// an overflowing viewport's and the hard floor's one reading
    /// (#1830).
    nonisolated static func endPads(gap: CGFloat) -> CGFloat {
        SpaceBarItemView.pad + max(gap, SpaceBarItemView.pad)
    }

    /// Where an overflowing viewport starts: where `contentStart`
    /// puts a run exactly `endPads` short of the axis.
    nonisolated static func overflowLead(
        gap: CGFloat,
        alignment: KiwiShelf.Alignment
    ) -> CGFloat {
        let pads = endPads(gap: gap)
        return contentStart(
            total: 0,
            axis: pads,
            alignment: alignment,
            pad: SpaceBarItemView.pad
        )
    }

    /// The active Space item's length — what the shelf's hard
    /// floor keeps in view (#1517); the longest item where none is
    /// active.
    static func activeExtent(
        items: [Item],
        depth: CGFloat,
        look: SpaceBarLook
    ) -> CGFloat {
        let lengths = itemLengths(
            items,
            depth: depth,
            look: look,
            frontFollows: false
        )
        if let index = items.firstIndex(where: \.active) {
            return lengths[index]
        }
        return lengths.max() ?? 0
    }

    /// Calculates item frames and front segment start coordinate,
    /// in `itemRun` coordinates: an overflowing run starts at zero
    /// and the run's frame carries the scroll.
    nonisolated static func runMetrics(
        lengths: [CGFloat],
        gap: CGFloat,
        frontExtent: CGFloat,
        strip: CGRect,
        viewport: CGFloat,
        horizontal: Bool,
        alignment: KiwiShelf.Alignment,
        pad: CGFloat
    ) -> RunMetrics {
        let total = runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: frontExtent
        )
        let cross = horizontal ? strip.height : strip.width
        var cursor =
            total > viewport
            ? 0
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
