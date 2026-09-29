import AppKit

/// Wheel, trackpad and drag-autoscroll travel for SpaceBarOverlay
/// (#385, #1517): a scroll moves `itemRun` alone and re-reads what
/// depends on the offset, never re-rendering every item and glass.
extension SpaceBarOverlay {
    /// The last render's run, as a scroll re-reads it.
    struct ScrollRun {
        let items: [Item]
        /// Item frames in `itemRun` coordinates, as drawn.
        let frames: [CGRect]
        let lengths: [CGFloat]
        /// The entries the fades count: the items, plus the front
        /// segment while it scrolls with them.
        let entries: [CGFloat]
        let front: CGFloat
        let total: CGFloat
        let viewport: CGFloat
        let gap: CGFloat
        let depth: CGFloat
        let horizontal: Bool
        let strip: CGRect
        let style: SpaceBarLook
        /// The drawn content, in `itemRun`'s coordinates where it
        /// `rides` the run, else in `root`'s (a pinned segment).
        let content: CGRect
        let rides: Bool
        /// The front segment while it scrolls with the run: its
        /// name is cut at the viewport's end, so a scroll re-lays it.
        let frontApp: SpaceBarItemView.App?
        let frontStart: CGFloat
    }

    /// A wheel or trackpad scroll (`ShelfScrollInput`): taken
    /// while entries are hidden, fluid rather than entry-aligned,
    /// and a manual scroll only where the offset moved. A trackpad
    /// moves the run directly, a wheel notch as one glide.
    func scroll(_ delta: ShelfScrollInput.Delta) -> Bool {
        guard isVisible, let run = scrollRun, run.total > run.viewport
        else { return false }
        let travel = ShelfScrollInput.travel(
            delta,
            itemStep: Self.scrollStep(lengths: run.entries, gap: run.gap)
        )
        if moveRun(to: scrollOffset + travel, animated: !delta.precise) {
            follow.scrolledByHand()
        }
        return true
    }

    /// Shifts the bar offset without forcing active follow — the
    /// drag autoscroll's step.
    func scroll(by delta: CGFloat) {
        follow.scrolledByHand()
        moveRun(to: scrollOffset + delta, animated: false)
    }

    /// The section's one scroll door (bars.md): moves the run to
    /// `target`, clamped, and re-reads what the last render derived
    /// from the offset — drop targets, fades, counts, the drawn
    /// content, a scrolling front segment, hover — never
    /// re-rendering; the shelf re-lays only where that moved the
    /// divider. The plate needs no re-read:
    /// an overflowing run's plate spans its strip at every offset
    /// (`BarPlate.frame`). Returns whether the offset moved.
    @discardableResult
    func moveRun(to target: CGFloat, animated: Bool) -> Bool {
        guard let run = scrollRun else { return false }
        let offset = Self.scrollOffset(
            current: target,
            lengths: run.lengths,
            gap: run.gap,
            frontExtent: run.front,
            activeIndex: nil,
            viewport: run.viewport,
            margin: 0
        )
        guard offset != scrollOffset else { return false }
        scrollOffset = offset
        let runFrame = ShelfOverflow.runFrame(
            in: itemContainer.bounds,
            offset: offset,
            horizontal: run.horizontal
        )
        BarMotion.runLayout {
            BarMotion.setFrame(itemRun, to: runFrame, animated: animated)
        }
        let fades = ShelfOverflow.fades(
            lengths: run.entries,
            gap: run.gap,
            total: run.total,
            offset: offset,
            viewport: run.viewport,
            depth: run.depth
        )
        recordHitFrames(
            items: run.items,
            frames: run.frames,
            runOrigin: runFrame.origin,
            strip: run.strip,
            fades: fades,
            horizontal: run.horizontal
        )
        layoutOverflow(
            fades,
            strip: run.strip,
            viewport: run.viewport,
            total: run.total,
            lengths: run.entries,
            gap: run.gap,
            horizontal: run.horizontal,
            style: run.style,
            depth: run.depth
        )
        if run.frontApp != nil {
            renderFrontSegment(
                run.frontApp,
                after: run.frontStart,
                strip: run.strip,
                nameBound: run.viewport + offset,
                style: run.style,
                horizontal: run.horizontal
            )
        }
        let before = contentFrame
        contentFrame =
            run.rides
            ? run.content.offsetBy(dx: runFrame.minX, dy: runFrame.minY)
            : run.content
        let length = run.horizontal ? run.strip.width : run.strip.height
        let moved = ShelfOverlay.dividerMoves(
            from: before,
            to: contentFrame,
            along: length,
            horizontal: run.horizontal
        )
        if moved { onRendered() }
        syncHoverToPointer()
        return true
    }
}
