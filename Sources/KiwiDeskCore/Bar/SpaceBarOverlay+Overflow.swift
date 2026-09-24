import AppKit

/// Space Bar overflow chrome and drag autoscroll (#385, #409,
/// #1517): the run fades on a side that hides entries, with a
/// count there that pages. The fading ends structurally exclude
/// every item's hit frame (`recordHitFrames`), so the autoscroll
/// and the drop-spring govern disjoint zones and never contend.
extension SpaceBarOverlay {
    /// Scroll geometry cached each render for the autoscroll path.
    struct ScrollGeom {
        let strip: CGRect
        let fades: ShelfOverflow.Fades
        let horizontal: Bool
        let step: CGFloat
        let maxOffset: CGFloat
        /// Trailing edge bound along axis (#409).
        let trailingAxis: CGFloat
    }

    /// Autoscroll timing parameters (#372, #385).
    nonisolated static let autoScrollInitialDelay: TimeInterval =
        0.2
    nonisolated static let autoScrollInterval: TimeInterval = 0.3

    /// Fades the run's hidden ends and sets each side's count
    /// (#1517); a count pages to the next entry boundary.
    func layoutOverflow(
        _ fades: ShelfOverflow.Fades,
        strip: CGRect,
        viewport: CGFloat,
        total: CGFloat,
        lengths: [CGFloat],
        gap: CGFloat,
        horizontal: Bool,
        style: SpaceBarLook,
        depth: CGFloat
    ) {
        ShelfFadeMask.apply(
            to: itemContainer,
            leading: fades.leading,
            trailing: fades.trailing,
            horizontal: horizontal
        )
        let font = style.identifierFontSize(forDepth: depth) * 0.8
        let ink = NSColor(kiwiHex: style.itemColor)
        let hoverInk = NSColor(kiwiHex: style.hoverItemColor)
        backCount.configure(
            count: fades.before,
            horizontal: horizontal,
            fontSize: font,
            ink: ink,
            hoverInk: hoverInk
        )
        forwardCount.configure(
            count: fades.after,
            horizontal: horizontal,
            fontSize: font,
            ink: ink,
            hoverInk: hoverInk
        )
        let container = itemContainer.frame
        backCount.place(in: container, atEnd: false)
        forwardCount.place(in: container, atEnd: true)
        let fade = max(fades.leading, fades.trailing)
        backCount.onPage = { [weak self] in
            self?.page(
                forward: false,
                lengths: lengths,
                gap: gap,
                viewport: viewport,
                fade: fade
            )
        }
        forwardCount.onPage = { [weak self] in
            self?.page(
                forward: true,
                lengths: lengths,
                gap: gap,
                viewport: viewport,
                fade: fade
            )
        }
        let axisEnd = horizontal ? container.maxX : container.maxY
        scrollGeom = ScrollGeom(
            strip: strip,
            fades: fades,
            horizontal: horizontal,
            step: Self.scrollStep(lengths: lengths, gap: gap),
            maxOffset: max(total - viewport, 0),
            trailingAxis: axisEnd
        )
    }

    /// Pages one way to the next entry boundary (`ShelfOverflow`).
    private func page(
        forward: Bool,
        lengths: [CGFloat],
        gap: CGFloat,
        viewport: CGFloat,
        fade: CGFloat
    ) {
        manuallyScrolled = true
        scrollOffset = ShelfOverflow.pageTarget(
            from: scrollOffset,
            lengths: lengths,
            gap: gap,
            viewport: viewport,
            fade: fade,
            forward: forward
        )
        render(followingActive: false)
    }

    /// Shifts bar offset and re-renders without forcing active follow.
    func scroll(by delta: CGFloat) {
        manuallyScrolled = true
        scrollOffset += delta
        render(followingActive: false)
    }

    /// Updates drag autoscroll state based on cursor position (#385).
    func updateDragAutoScroll(atGlobal cocoaPoint: CGPoint) {
        guard isVisible, let geom = scrollGeom else {
            cancelDragAutoScroll()
            return
        }
        let ax = GeometryUtils.axPoint(cocoaPoint)
        guard geom.strip.contains(ax) else {
            cancelDragAutoScroll()
            return
        }
        let local = CGPoint(
            x: ax.x - geom.strip.minX,
            y: ax.y - geom.strip.minY
        )
        let hit = Self.fadeHit(
            at: local,
            strip: geom.strip,
            fades: geom.fades,
            trailingAxis: geom.trailingAxis,
            horizontal: geom.horizontal
        )
        let direction = scrollableDirection(hit, geom: geom)
        backCount.setDragHover(direction == .back)
        forwardCount.setDragHover(direction == .forward)
        setAutoScrollDirection(direction)
    }

    /// Cancels active autoscroll task and clears drag hovers.
    func cancelDragAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        autoScrollDirection = nil
        backCount.setDragHover(false)
        forwardCount.setDragHover(false)
    }

    private func scrollableDirection(
        _ hit: ScrollDirection?,
        geom: ScrollGeom
    ) -> ScrollDirection? {
        switch hit {
        case .back where scrollOffset > 0.5:
            return .back
        case .forward where geom.maxOffset - scrollOffset > 0.5:
            return .forward
        default:
            return nil
        }
    }

    private func setAutoScrollDirection(_ direction: ScrollDirection?) {
        guard direction != autoScrollDirection else { return }
        autoScrollDirection = direction
        autoScrollTask?.cancel()
        autoScrollTask = nil
        guard direction != nil else { return }
        autoScrollTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: nanos(Self.autoScrollInitialDelay)
            )
            while !Task.isCancelled {
                guard let self, self.autoScrollTick() else {
                    break
                }
                try? await Task.sleep(
                    nanoseconds: nanos(Self.autoScrollInterval)
                )
            }
        }
    }

    private func autoScrollTick() -> Bool {
        guard let direction = autoScrollDirection,
            let geom = scrollGeom
        else { return false }
        let before = scrollOffset
        scroll(by: direction == .forward ? geom.step : -geom.step)
        guard abs(scrollOffset - before) >= 0.5 else {
            autoScrollDirection = nil
            backCount.setDragHover(false)
            forwardCount.setDragHover(false)
            return false
        }
        return true
    }
}

/// Seconds → nanoseconds for `Task.sleep`.
private func nanos(_ seconds: TimeInterval) -> UInt64 {
    UInt64(seconds * 1_000_000_000)
}
