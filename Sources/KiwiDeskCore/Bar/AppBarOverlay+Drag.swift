import AppKit

/// Drag-and-drop reordering: an item (a single window or a
/// whole group) follows the cursor along the bar axis while
/// the other items reflow live around the slot it would land
/// in; dropping reports (from, to) through `onMove`, and the
/// core rewrites the window order.
extension AppBarOverlay {
    /// The dragged item rides along the axis (cross-axis
    /// pinned), floating above its siblings.
    func dragMoved(
        _ view: AppBarItemView,
        to point: CGPoint
    ) {
        guard let m = lastMetrics,
            let container = view.superview
        else { return }
        if container.subviews.last !== view {
            container.addSubview(view)
        }
        var frame = view.frame
        if m.horizontal {
            frame.origin.x = point.x - frame.width / 2
        } else {
            frame.origin.y = point.y - frame.height / 2
        }
        view.frame = frame
        reflow(around: view, m: m)
    }

    func dragEnded(_ view: AppBarItemView) {
        guard let m = lastMetrics,
            let from = itemViews.firstIndex(of: view)
        else { return }
        let to = Self.dropIndex(
            center: m.horizontal
                ? view.frame.midX : view.frame.midY,
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
        guard let container = dragged.superview,
            let from = itemViews.firstIndex(of: dragged)
        else { return }
        let to = Self.dropIndex(
            center: m.horizontal
                ? dragged.frame.midX : dragged.frame.midY,
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
            in: container.bounds,
            gap: m.gap,
            horizontal: m.horizontal,
            alignment: m.alignment,
            scrolledBy: scrollOffset
        )
        for (index, view) in order.enumerated()
        where view !== dragged {
            view.frame = frames[index]
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
