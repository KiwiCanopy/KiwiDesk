import AppKit

/// Drag-and-drop item reordering and reflow for AppBarOverlay.
extension AppBarOverlay {
    /// The tiled items, which alone reorder: a float has no slot
    /// in the row (#1826).
    private var tiledCount: Int {
        lastShown.map { Self.tiledCount($0.items) } ?? 0
    }

    /// Moves dragged item view and live reflows sibling slots.
    func dragMoved(
        _ view: AppBarItemView,
        to windowPoint: CGPoint
    ) {
        guard let m = lastMetrics,
            (itemViews.firstIndex(of: view).map { $0 < tiledCount }) == true
        else { return }
        let mover = draggableView(for: view)
        let point = itemRun.convert(windowPoint, from: nil)
        if itemRun.subviews.last !== mover {
            itemRun.addSubview(mover)
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
            let from = itemViews.firstIndex(of: view),
            from < tiledCount
        else { return }
        let mover = draggableView(for: view)
        let to = Self.dropIndex(
            center: m.horizontal
                ? mover.frame.midX : mover.frame.midY,
            start: contentStart(m),
            slot: m.slot,
            gap: m.gap,
            count: tiledCount
        )
        // The drag set frames by hand, so the refresh the move
        // asks for must draw though its input repeats (#1901); a
        // move that refreshes nothing is snapped back here.
        let before = draws
        invalidateRender()
        if to != from { onMove(from, to) }
        if draws == before { redrawShown() }
    }

    /// Makes the next show draw though its input repeats — for a
    /// path that leaves views where a draw of the same input
    /// would not put them, which a drop is (#1901).
    func invalidateRender() { drawnEnvironment = nil }

    /// Redraws the shown input, recording what the draw read.
    func redrawShown() {
        drawnEnvironment = .current
        render(followingFocus: false)
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
            count: tiledCount
        )
        var order = itemViews
        order.remove(at: from)
        order.insert(dragged, at: min(to, order.count))
        let frames = Self.itemFrames(in: itemRun.bounds, m: m)
        for (index, view) in order.enumerated()
        where view !== dragged {
            draggableView(for: view).frame = frames[index]
        }
    }

    /// Where the first item's slot starts along the axis in
    /// `itemRun` coordinates (mirrors `frames`, alignment
    /// included — drop-index math must see the same origin
    /// the rendered slots use).
    private func contentStart(_ m: Metrics) -> CGFloat {
        if m.total > m.viewport { return 0 }
        return Self.alignedStart(
            slack: m.viewport - m.total,
            alignment: m.alignment
        )
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
