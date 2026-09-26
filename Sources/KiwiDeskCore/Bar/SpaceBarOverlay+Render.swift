import AppKit

/// Layout and rendering passes for `SpaceBarOverlay` (#407, #409).
extension SpaceBarOverlay {
    /// Executes one layout pass over the last shown state.
    func render(followingActive: Bool) {
        guard let state = lastShown else { return }
        let (items, frontApp, strip, _, stateMarkColors) = state
        // The one place the stored style becomes the drawn one
        // (#1374): glass stands down while transparency is reduced.
        let style = LiquidGlassGate.rendered(state.style)
        syncItemViewCount(items.count)
        let horizontal = style.edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        let axis = horizontal ? strip.width : strip.height
        let gap = style.itemGap
        let leadsWithLayer = Self.leadsWithLayer(items)
        let lengths = Self.itemLengths(items, depth: depth, gap: gap)
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
        let fadeRoom = ShelfArrangement.fadeRoom(thickness: depth, gap: gap)
        let pinFront =
            total > axis && frontApp != nil
            && front < axis - fadeRoom
        let scrolledFront = pinFront ? 0 : front
        let spacesAxis = pinFront ? axis - front : axis
        let scrolledTotal = Self.runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: scrolledFront
        )
        // No arrow zones: the run fills its section and fades on
        // a side that hides entries (#1517).
        let inset: CGFloat = 0
        let viewport = spacesAxis
        scrollOffset = Self.scrollOffset(
            current: scrollOffset,
            lengths: lengths,
            gap: gap,
            frontExtent: scrolledFront,
            activeIndex: followingActive ? activeIndex(items) : nil,
            viewport: viewport,
            margin: ShelfOverflow.followMargin(
                gap: gap,
                depth: depth,
                viewport: viewport
            )
        )
        // The front segment scrolls with the run unless pinned, so
        // it is an entry the fades count and a page reaches.
        let runEntries =
            scrolledFront > 0 ? lengths + [scrolledFront] : lengths
        let fades = ShelfOverflow.fades(
            lengths: runEntries,
            gap: gap,
            total: scrolledTotal,
            offset: scrollOffset,
            viewport: viewport,
            depth: depth
        )
        _ = placeItemContainer(
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
                gap: gap,
                horizontal: horizontal,
                fit: style.backgroundFit
            )
        self.plateFrame = plateFrame
        let hosting = glassHosting(style)
        prepareGlassHosting(hosting, pinnedFront: pinFront)
        let itemFrames = layoutLayerDivider(
            frames: metrics.itemFrames,
            leads: leadsWithLayer,
            gap: gap,
            strip: strip,
            horizontal: horizontal,
            style: style
        )
        recordHitFrames(
            items: items,
            frames: itemFrames,
            strip: strip,
            fades: fades,
            horizontal: horizontal
        )
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            view.frame = itemFrames[index]
            view.configure(
                identity: item.identity,
                spaceGlyph: item.spaceGlyph,
                apps: item.apps,
                active: item.active,
                horizontal: horizontal,
                style: style,
                stateMarkColors: stateMarkColors,
                overflow: item.overflow,
                focusInOverflow: item.focusInOverflow,
                held: item.held
            )
            view.onSelect = { [weak self] space in
                self?.onSelect(space)
            }
            view.isFirstInRun = index == 0
            view.isLastInRun =
                index == items.count - 1 && frontApp == nil
        }
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
            frames: itemFrames,
            style: style,
            depth: horizontal ? strip.height : strip.width
        )
        layoutOverflow(
            fades,
            strip: strip,
            viewport: viewport,
            total: scrolledTotal,
            lengths: runEntries,
            gap: gap,
            horizontal: horizontal,
            style: style,
            depth: depth
        )
        root.isHidden = false
        for view in itemViews { view.syncHoverToPointer() }
        onRendered()
    }

    /// Index of the active Space for scroll-follow navigation.
    private func activeIndex(_ items: [Item]) -> Int? {
        items.firstIndex(where: \.active)
    }
}
