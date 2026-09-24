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
        for (view, hidden) in [
            (backCount, fades.before), (forwardCount, fades.after),
        ] {
            view.configure(
                count: hidden,
                horizontal: m.horizontal,
                fontSize: font,
                ink: ink,
                hoverInk: hoverInk
            )
            place(view, atEnd: view === forwardCount, m.horizontal)
        }
        let fade = max(fades.leading, fades.trailing)
        backCount.onPage = { [weak self] in
            self?.page(forward: false, lengths: lengths, m: m, fade: fade)
        }
        forwardCount.onPage = { [weak self] in
            self?.page(forward: true, lengths: lengths, m: m, fade: fade)
        }
    }

    /// Sits a count on its fading end of the viewport.
    private func place(
        _ view: ShelfCountView,
        atEnd: Bool,
        _ horizontal: Bool
    ) {
        guard !view.isHidden else { return }
        let container = itemContainer.frame
        let length = view.fittingLength
        view.frame =
            horizontal
            ? CGRect(
                x: atEnd ? container.maxX - length : container.minX,
                y: container.minY,
                width: length,
                height: container.height
            )
            : CGRect(
                x: container.minX,
                y: atEnd ? container.maxY - length : container.minY,
                width: container.width,
                height: length
            )
    }

    /// Pages one way to the next slot boundary (`ShelfOverflow`).
    private func page(
        forward: Bool,
        lengths: [CGFloat],
        m: Metrics,
        fade: CGFloat
    ) {
        manuallyScrolled = true
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
}
