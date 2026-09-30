import AppKit

/// Overflow chrome for AppBarOverlay (#1517): the run fades on a
/// side that hides windows, with a count there that pages to the
/// next slot boundary.
extension AppBarOverlay {
    func layoutOverflow(
        strip: CGRect,
        m: Metrics,
        style: AppBarLook
    ) {
        let lengths = m.lengths
        let depth = m.horizontal ? strip.height : strip.width
        let fades = ShelfOverflow.fades(
            lengths: lengths,
            gap: m.gap,
            total: m.total,
            offset: scrollOffset,
            viewport: m.viewport,
            depth: depth
        )
        ShelfFadeMask.apply(
            to: itemContainer,
            leading: fades.leading,
            trailing: fades.trailing,
            horizontal: m.horizontal
        )
        let font = style.resolvedFontSize(forDepth: depth) * 0.9
        let ink = NSColor(kiwiHex: style.itemColor)
        let hoverInk = NSColor(kiwiHex: style.hoverItemColor)
        let hoverFill = NSColor(kiwiHex: style.hoverFillColor)
        let chipRadius = style.resolvedCornerRadius(
            forThickness: depth - 2 * ShelfCountView.chipInset
        )
        for (view, hidden) in [
            (backCount, fades.before), (forwardCount, fades.after),
        ] {
            view.configure(
                count: hidden,
                horizontal: m.horizontal,
                fontSize: font,
                shelf: style.shelf,
                ink: ink,
                hoverInk: hoverInk,
                hoverFill: hoverFill,
                chipRadius: chipRadius
            )
            view.place(in: itemContainer.frame, atEnd: view === forwardCount)
        }
        let fade = max(fades.leading, fades.trailing)
        backCount.onPage = { [weak self] in
            self?.page(forward: false, lengths: lengths, m: m, fade: fade)
        }
        forwardCount.onPage = { [weak self] in
            self?.page(forward: true, lengths: lengths, m: m, fade: fade)
        }
    }

    /// A wheel or trackpad scroll (`ShelfScrollInput`): taken
    /// while entries are hidden, fluid rather than slot-aligned,
    /// and a manual scroll only where the offset moved — a
    /// trackpad directly, a wheel notch as one glide.
    func scroll(_ delta: ShelfScrollInput.Delta) -> Bool {
        guard isVisible, let m = lastMetrics, m.total > m.viewport
        else { return false }
        let travel = ShelfScrollInput.travel(delta, itemStep: m.slot + m.gap)
        if moveRun(to: scrollOffset + travel, animated: !delta.precise) {
            follow.scrolledByHand()
        }
        return true
    }

    /// Pages one way to the next slot boundary (`ShelfOverflow`).
    private func page(
        forward: Bool,
        lengths: [CGFloat],
        m: Metrics,
        fade: CGFloat
    ) {
        follow.scrolledByHand()
        let target = ShelfOverflow.pageTarget(
            from: scrollOffset,
            lengths: lengths,
            gap: m.gap,
            viewport: m.viewport,
            fade: fade,
            forward: forward
        )
        moveRun(to: target, animated: true)
    }

    /// The section's one scroll door (bars.md): moves `itemRun` to
    /// `target`, clamped, and re-reads what the last render derived
    /// from the offset — fades, counts, the drawn content, hover —
    /// never re-rendering; the shelf re-lays only where that moved
    /// the divider.
    /// The plate needs no re-read: an overflowing run's plate spans
    /// its strip at every offset (`BarPlate.frame`). Returns
    /// whether the offset moved.
    @discardableResult
    private func moveRun(to target: CGFloat, animated: Bool) -> Bool {
        guard let m = lastMetrics, let state = lastShown,
            let style = drawnStyle
        else { return false }
        let offset = Self.scrollOffset(
            current: target,
            activeIndex: nil,
            lengths: m.lengths,
            gap: m.gap,
            axis: m.viewport,
            margin: 0
        )
        guard offset != scrollOffset else { return false }
        scrollOffset = offset
        let runFrame = ShelfOverflow.runFrame(
            in: itemContainer.bounds,
            offset: offset,
            horizontal: m.horizontal
        )
        BarMotion.runLayout {
            BarMotion.setFrame(itemRun, to: runFrame, animated: animated)
        }
        layoutOverflow(strip: state.strip, m: m, style: style)
        let before = contentFrame
        contentFrame = runContent.offsetBy(
            dx: runFrame.minX + itemContainer.frame.minX,
            dy: runFrame.minY + itemContainer.frame.minY
        )
        let length = m.horizontal ? state.strip.width : state.strip.height
        let moved = ShelfOverlay.dividerMoves(
            from: before,
            to: contentFrame,
            along: length,
            horizontal: m.horizontal
        )
        if moved { onRendered() }
        syncHoverToPointer()
        return true
    }

    /// Re-reads every hover this section draws from the resting
    /// pointer (#1665); `ShelfManager.relayout` calls it once the
    /// section is placed.
    func syncHoverToPointer() {
        for view in itemViews { view.syncHoverToPointer() }
        backCount.syncHoverToPointer()
        forwardCount.syncHoverToPointer()
    }
}
