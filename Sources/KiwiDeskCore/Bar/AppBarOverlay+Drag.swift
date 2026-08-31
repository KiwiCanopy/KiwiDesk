import AppKit

/// Drag-and-drop item reordering and reflow for AppBarOverlay.
extension AppBarOverlay {
    /// Moves dragged item view and live reflows sibling slots.
    func dragMoved(
        _ view: AppBarItemView,
        to windowPoint: CGPoint
    ) {
        guard let m = lastMetrics else { return }
        // Leave glass hug mode so the mover and its siblings share
        // `itemContainer`'s coordinate space.
        spanPlainGlassForDrag()
        let mover = draggableView(for: view)
        let point = itemContainer.convert(windowPoint, from: nil)
        if itemContainer.subviews.last !== mover {
            itemContainer.addSubview(mover)
        }
        var frame = mover.frame
        if m.horizontal {
            frame.origin.x = point.x - frame.width / 2
        } else {
            frame.origin.y = point.y - frame.height / 2
        }
        mover.frame = frame
        reflow(around: view, m: m)
    }

    func dragEnded(_ view: AppBarItemView) {
        guard let m = lastMetrics,
            let from = itemViews.firstIndex(of: view)
        else { return }
        let mover = draggableView(for: view)
        let to = Self.dropIndex(
            center: m.horizontal
                ? mover.frame.midX : mover.frame.midY,
            start: contentStart(m),
            slot: m.slot,
            gap: m.gap,
            count: itemViews.count
        )
        if to == from {
            // Nothing moved: snap the item back into line.
            render(followingFocus: false)
        } else {
            onMove(from, to)
        }
    }

    /// The non-dragged items take the frames of the order
    /// the drop would produce, so the gap tracks the cursor.
    private func reflow(
        around dragged: AppBarItemView,
        m: Metrics
    ) {
        guard let from = itemViews.firstIndex(of: dragged)
        else { return }
        let draggedMover = draggableView(for: dragged)
        let to = Self.dropIndex(
            center: m.horizontal
                ? draggedMover.frame.midX : draggedMover.frame.midY,
            start: contentStart(m),
            slot: m.slot,
            gap: m.gap,
            count: itemViews.count
        )
        var order = itemViews
        order.remove(at: from)
        order.insert(dragged, at: min(to, order.count))
        let frames = Self.frames(
            lengths: Array(
                repeating: m.slot,
                count: order.count
            ),
            in: itemContainer.bounds,
            gap: m.gap,
            horizontal: m.horizontal,
            alignment: m.alignment,
            scrolledBy: scrollOffset
        )
        for (index, view) in order.enumerated()
        where view !== dragged {
            draggableView(for: view).frame = frames[index]
        }
    }

    /// Where the first item's slot starts along the axis in
    /// viewport coordinates (mirrors `frames`, alignment
    /// included — drop-index math must see the same origin
    /// the rendered slots use).
    private func contentStart(_ m: Metrics) -> CGFloat {
        if m.total > m.viewport { return -scrollOffset }
        switch m.alignment {
        case .start: return 0
        case .center: return (m.viewport - m.total) / 2
        case .end: return m.viewport - m.total
        }
    }

    /// The slot whose span contains `center`, clamped to the
    /// item range. Pure math, unit-tested.
    nonisolated static func dropIndex(
        center: CGFloat,
        start: CGFloat,
        slot: CGFloat,
        gap: CGFloat,
        count: Int
    ) -> Int {
        guard count > 0, slot + gap > 0 else { return 0 }
        let relative = (center - start) / (slot + gap)
        return min(
            max(Int(relative.rounded(.down)), 0),
            count - 1
        )
    }
}
