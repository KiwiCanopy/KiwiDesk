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
        let count = itemViews.count
        let lengths = Array(repeating: m.slot, count: count)
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
        let font = style.resolvedFontSize(forThickness: depth) * 0.9
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
    /// and a manual scroll only where the offset moved.
    func scroll(_ delta: ShelfScrollInput.Delta) -> Bool {
        guard isVisible, let m = lastMetrics, m.total > m.viewport
        else { return false }
        let before = scrollOffset
        scrollOffset += ShelfScrollInput.travel(
            delta,
            itemStep: m.slot + m.gap
        )
        render(followingFocus: false)
        if scrollOffset != before { follow.scrolledByHand() }
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
        scrollOffset = ShelfOverflow.pageTarget(
            from: scrollOffset,
            lengths: lengths,
            gap: m.gap,
            viewport: m.viewport,
            fade: fade,
            forward: forward
        )
        render(followingFocus: false)
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
