import AppKit

/// The Space Bar's one layout pass. Split from `SpaceBarOverlay`
/// for file size (§2): the stored views/state and the show/hide
/// surface stay in the main file; the render composition — item
/// run, scroll viewport, the pinned front segment (#409), the
/// glass hosting, and the arrows — lives here.
extension SpaceBarOverlay {
    /// One layout pass over the last shown state. `show()`
    /// follows the active Space into view; a manual arrow or
    /// autoscroll re-renders without that adjustment so it isn't
    /// snapped straight back (the App Bar's `followingFocus`).
    func render(followingActive: Bool) {
        guard let state = lastShown else { return }
        let (items, frontApp, strip, style, stateMarkColors) = state
        let panel = self.panel ?? makePanel()
        self.panel = panel
        styleContainer(panel, style: style, strip: strip)
        syncItemViewCount(items.count)
        let horizontal = style.edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        let axis = horizontal ? strip.width : strip.height
        let gap = style.itemGap
        let lengths = items.map { item in
            style.itemSize > 0
                ? style.itemSize
                : SpaceBarItemView.autoLength(
                    appCount: item.apps.count,
                    overflow: item.overflow,
                    depth: depth
                )
        }
        // While the whole run fits, items plus the trailing front
        // segment align as ONE run (an end-aligned bar ends at the
        // rim including the segment) — the segment is the run's
        // tail, unchanged. When the run OVERFLOWS, the segment is
        // pinned to the trailing rim in a fixed band and only the
        // Spaces scroll behind the arrows (#409), so the front app
        // never scrolls out of view. The overflow threshold still
        // weighs items + segment together, so the bar starts
        // scrolling at exactly the same width as before.
        let front = frontExtent(
            frontApp,
            depth: depth,
            horizontal: horizontal,
            style: style
        )
        let total = Self.runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: front
        )
        // Pin only when the trailing band still leaves the Spaces a
        // real viewport (room for both arrow zones); a pathological
        // near-full-width app name falls back to scrolling with the
        // run rather than collapsing the Spaces to nothing.
        let arrowRoom = 2 * (BarArrowView.zone + gap)
        let pinFront =
            total > axis && frontApp != nil
            && front < axis - arrowRoom
        // Pinned: the segment owns the trailing `front` band, so the
        // Spaces scroll in the axis that remains and the segment
        // leaves the scrolled run. Not pinned: the segment rides the
        // run as its tail, exactly as before.
        let scrolledFront = pinFront ? 0 : front
        let spacesAxis = pinFront ? axis - front : axis
        let scrolledTotal = Self.runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: scrolledFront
        )
        let (inset, viewport) = Self.scrollViewport(
            axis: spacesAxis,
            total: scrolledTotal,
            gap: gap
        )
        scrollOffset = Self.scrollOffset(
            current: scrollOffset,
            lengths: lengths,
            gap: gap,
            frontExtent: scrolledFront,
            activeIndex: followingActive ? activeIndex(items) : nil,
            viewport: viewport,
            margin: gap
        )
        let viewportRect = placeItemContainer(
            inset: inset,
            viewport: viewport,
            strip: strip,
            horizontal: horizontal
        )
        let metrics = Self.runMetrics(
            lengths: lengths,
            gap: gap,
            frontExtent: scrolledFront,
            strip: strip,
            viewport: viewport,
            horizontal: horizontal,
            alignment: style.alignment,
            pad: SpaceBarItemView.pad,
            scrollOffset: scrollOffset
        )
        // The shared plate (plain fill / glass) hugs or spans
        // per `background_fit`. With no arrow inset the
        // viewport is the strip, so viewport-local run
        // coordinates are already strip-local; while inset > 0
        // the plate is full anyway.
        let runStart: CGFloat
        if let first = metrics.itemFrames.first {
            runStart = horizontal ? first.minX : first.minY
        } else {
            runStart = metrics.frontStart
        }
        // A pinned segment (#409) means the run fills the strip
        // (Spaces + arrows + segment), so the shared plate spans it
        // — nothing to hug, and the pinned segment must sit on the
        // same continuous plate as the Spaces.
        let plateFrame =
            pinFront
            ? CGRect(
                x: 0,
                y: 0,
                width: strip.width,
                height: strip.height
            )
            : BarPlate.frame(
                strip: strip,
                runStart: runStart,
                runTotal: total,
                inset: inset,
                gap: gap,
                horizontal: horizontal,
                fit: style.backgroundFit
            )
        // The one hosting mode for this render (#407): prepared
        // (non-target teardown) here, then installed post-passes
        // once the item frames are laid out.
        let hosting = glassHosting(style, overflow: inset > 0)
        prepareGlassHosting(
            hosting,
            panel: panel,
            style: style,
            strip: strip,
            plateFrame: plateFrame,
            viewport: viewportRect
        )
        recordHitFrames(
            items: items,
            frames: metrics.itemFrames,
            strip: strip
        )
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            view.frame = metrics.itemFrames[index]
            view.configure(
                space: item.space,
                spaceGlyph: item.spaceGlyph,
                apps: item.apps,
                active: item.active,
                horizontal: horizontal,
                style: style,
                stateMarkColors: stateMarkColors,
                overflow: item.overflow,
                focusInOverflow: item.focusInOverflow
            )
            view.onSelect = { [weak self] space in
                self?.onSelect(space)
            }
            // Only the run's outer items meet a rounded plate end.
            // The trailing end is the front-app segment's when one
            // trails, so the last Space item clips its trailing
            // corner only without a front app.
            view.isFirstInRun = index == 0
            view.isLastInRun =
                index == items.count - 1 && frontApp == nil
        }
        // Host the segment in the panel content (outside the
        // clipping viewport) while pinned, so it stays put as the
        // Spaces scroll; in the viewport as the run's tail while it
        // fits. Pinned, its divider sits one `gap` past where the
        // forward arrow ends (`spacesAxis`), mirroring the run-tail
        // spacing; the name may still reach the strip rim.
        frontHost = pinFront ? panel.contentView : itemContainer
        renderFrontSegment(
            frontApp,
            after: pinFront ? spacesAxis + gap : metrics.frontStart,
            strip: strip,
            nameBound: pinFront ? axis : viewport,
            style: style,
            horizontal: horizontal
        )
        // Install the target hosting from the now-laid-out item
        // frames (per-box glass and the plain-glass run both position
        // from them, so this runs after the item + front passes).
        // #407: one dispatch, no per-mode branching at the call site.
        installGlassHosting(
            hosting,
            panel: panel,
            frames: metrics.itemFrames,
            viewport: viewportRect,
            plateFrame: plateFrame,
            pinnedFront: pinFront,
            style: style,
            depth: horizontal ? strip.height : strip.width
        )
        layoutArrows(
            strip: strip,
            inset: inset,
            viewport: viewport,
            total: scrolledTotal,
            trailingAxis: spacesAxis,
            lengths: lengths,
            gap: gap,
            horizontal: horizontal,
            style: style
        )
        panel.setFrame(
            GeometryUtils.flip(
                strip,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// The index of the active Space, for scroll-follow.
    private func activeIndex(_ items: [Item]) -> Int? {
        items.firstIndex(where: \.active)
    }
}
