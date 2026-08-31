import AppKit

/// Layout and rendering passes for `SpaceBarOverlay` (#407, #409).
extension SpaceBarOverlay {
    /// Executes one layout pass over the last shown state.
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
        // Pin only while the trailing band leaves the Spaces a
        // real viewport; a pathological near-full-width app name
        // falls back to scrolling with the run rather than
        // collapsing the Spaces to nothing (#409).
        let arrowRoom = 2 * (BarArrowView.zone + gap)
        let pinFront =
            total > axis && frontApp != nil
            && front < axis - arrowRoom
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
        let runStart: CGFloat
        if let first = metrics.itemFrames.first {
            runStart = horizontal ? first.minX : first.minY
        } else {
            runStart = metrics.frontStart
        }
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
            view.isFirstInRun = index == 0
            view.isLastInRun =
                index == items.count - 1 && frontApp == nil
        }
        frontHost = pinFront ? panel.contentView : itemContainer
        renderFrontSegment(
            frontApp,
            after: pinFront ? spacesAxis + gap : metrics.frontStart,
            strip: strip,
            nameBound: pinFront ? axis : viewport,
            style: style,
            horizontal: horizontal
        )
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

    /// Index of the active Space for scroll-follow navigation.
    private func activeIndex(_ items: [Item]) -> Int? {
        items.firstIndex(where: \.active)
    }
}
