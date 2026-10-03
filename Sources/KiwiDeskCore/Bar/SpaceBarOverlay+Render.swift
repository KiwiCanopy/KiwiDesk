import AppKit

/// Layout and rendering passes for `SpaceBarOverlay` (#407, #409).
extension SpaceBarOverlay {
    /// Executes one layout pass over the last shown state;
    /// `slotChanged` says the section's slot is not the one the
    /// last pass drew into.
    func render(followingActive: Bool, slotChanged: Bool = false) {
        guard let state = lastShown else { return }
        let drawnContent = contentFrame
        let drawnRun = itemRun.convert(CGPoint.zero, to: root)
        let items = state.items
        let frontApp = state.frontApp
        let strip = state.strip
        let stateMarkColors = state.stateMarkColors
        // The one place the stored style becomes the drawn one
        // (#1374): glass stands down while transparency is reduced.
        let style = LiquidGlassGate.rendered(state.style)
        syncItemViewCount(items.count)
        let horizontal = style.edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        let axis = horizontal ? strip.width : strip.height
        let gap = style.itemGap
        let leadsWithLayer = Self.leadsWithLayer(items)
        let lengths = Self.itemLengths(
            items,
            depth: depth,
            look: style,
            frontFollows: frontApp != nil
        )
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
        // An overflowing run keeps the end pads a fitting one has,
        // where its alignment puts them, so crossing into overflow
        // starts the scroll and moves no end (#1830).
        let pads = Self.endPads(gap: gap)
        let pinFront =
            total > axis - pads && frontApp != nil
            && front < axis - fadeRoom
        let scrolledFront = pinFront ? 0 : front
        // A pinned segment keeps the gap the run puts before it.
        let spacesAxis = pinFront ? axis - front - gap : axis
        let scrolledTotal = Self.runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: scrolledFront
        )
        // No arrow zones: the run fades on a side that hides
        // entries (#1517).
        let overflows = scrolledTotal > spacesAxis - pads
        let inset =
            overflows
            ? Self.overflowLead(gap: gap, alignment: style.alignment) : 0
        let viewport = max(overflows ? spacesAxis - pads : spacesAxis, 0)
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
        let runFrame = ShelfOverflow.runFrame(
            in: itemContainer.bounds,
            offset: scrollOffset,
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
            pad: SpaceBarItemView.pad
        )
        let runStart =
            inset
            + (metrics.itemFrames.first.map {
                horizontal ? $0.minX : $0.minY
            } ?? metrics.frontStart)
            + (horizontal ? runFrame.minX : runFrame.minY)
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
        contentFrame = BarPlate.content(
            strip: strip,
            runStart: pinFront ? 0 : runStart,
            runTotal: pinFront ? axis : total,
            insets: pinFront
                ? .zero
                : Self.contentInsets(
                    items: items,
                    depth: depth,
                    look: style,
                    frontFollows: frontApp != nil
                ),
            horizontal: horizontal
        )
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
            runOrigin: runFrame.origin,
            strip: strip,
            fades: fades,
            horizontal: horizontal
        )
        scrollRun = ScrollRun(
            items: items,
            frames: itemFrames,
            lengths: lengths,
            entries: runEntries,
            front: scrolledFront,
            total: scrolledTotal,
            viewport: viewport,
            gap: gap,
            depth: depth,
            horizontal: horizontal,
            strip: strip,
            style: style,
            content: pinFront
                ? contentFrame
                : contentFrame.offsetBy(
                    dx: -runFrame.minX,
                    dy: -runFrame.minY
                ),
            rides: !pinFront,
            frontApp: pinFront ? nil : frontApp,
            frontStart: metrics.frontStart
        )
        let glides = recordGlide(
            items,
            content: style.inactiveContent,
            slotChanged: slotChanged,
            horizontal: horizontal
        )
        inlineResizeShift =
            contentFrame.minX - drawnContent.minX
            + drawnRun.x - itemContainer.frame.minX - runFrame.minX
        BarMotion.runLayout { moveFrame(itemRun, runFrame, glides) }
        placeItems(itemFrames, glides: glides)
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            view.glyphActions = glyphActions
            view.configure(
                identity: item.identity,
                spaceGlyph: item.spaceGlyph,
                apps: item.apps,
                active: item.active,
                horizontal: horizontal,
                style: style,
                stateMarkColors: stateMarkColors,
                before: item.before,
                after: item.after,
                drawn: item.drawn,
                marker: item.marker,
                collapse: item.collapse
            )
            view.onSelect = { [weak self] space in
                self?.onSelect(space)
            }
            view.onPointerInside = { [weak self] space, drawn, inside in
                self?.onStripHover(space, drawn, inside)
            }
            let place = Self.runPlace(
                index: index,
                count: items.count,
                frontFollows: frontApp != nil
            )
            view.isFirstInRun = place.first
            view.isLastInRun = place.last
        }
        renderFrontSegment(
            frontApp,
            after: pinFront ? spacesAxis + gap : metrics.frontStart,
            strip: strip,
            nameBound: pinFront ? axis : viewport + scrollOffset,
            style: style,
            horizontal: horizontal
        )
        let placeGlass = {
            self.installGlassHosting(
                hosting,
                frames: itemFrames,
                style: style,
                depth: horizontal ? strip.height : strip.width,
                animated: glides || self.resizesInlineTitles
            )
        }
        if resizesInlineTitles {
            BarMotion.runPlateGlide(placeGlass)
        } else {
            BarMotion.runLayout(placeGlass)
        }
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
        onRendered()
    }

    /// Index of the active Space for scroll-follow navigation.
    func activeIndex(_ items: [Item]) -> Int? {
        items.firstIndex(where: \.active)
    }
}
