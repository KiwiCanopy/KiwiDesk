import AppKit

/// Space Bar overflow scroll chrome and drag autoscroll (#385, #409).
extension SpaceBarOverlay {
    /// Scroll geometry cached each render for the autoscroll path.
    struct ScrollGeom {
        let strip: CGRect
        let inset: CGFloat
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

    /// Configures scroll arrows based on overflow and scroll offset (#409).
    func layoutArrows(
        strip: CGRect,
        inset: CGFloat,
        viewport: CGFloat,
        total: CGFloat,
        trailingAxis: CGFloat,
        lengths: [CGFloat],
        gap: CGFloat,
        horizontal: Bool,
        style: SpaceBarStyle
    ) {
        let maxOffset = max(total - viewport, 0)
        let overflowing = inset > 0
        backArrow.isHidden = !overflowing || scrollOffset <= 0.5
        forwardArrow.isHidden =
            !overflowing || maxOffset - scrollOffset <= 0.5
        let zone = BarArrowView.zone
        backArrow.frame =
            horizontal
            ? CGRect(x: 0, y: 0, width: zone, height: strip.height)
            : CGRect(x: 0, y: 0, width: strip.width, height: zone)
        forwardArrow.frame =
            horizontal
            ? CGRect(
                x: trailingAxis - zone,
                y: 0,
                width: zone,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: trailingAxis - zone,
                width: strip.width,
                height: zone
            )
        let colors = BarArrowColors(
            text: NSColor(kiwiHex: style.itemColor),
            hoverText: NSColor(kiwiHex: style.hoverItemColor),
            box: NSColor(kiwiHex: style.fillColor),
            hover: NSColor(kiwiHex: style.hoverFillColor),
            cornerRoundness: style.cornerRoundness
        )
        backArrow.configure(
            glyph: horizontal ? "◂" : "▴",
            colors: colors
        )
        forwardArrow.configure(
            glyph: horizontal ? "▸" : "▾",
            colors: colors
        )
        let step = Self.scrollStep(lengths: lengths, gap: gap)
        backArrow.onClick = { [weak self] in
            self?.scroll(by: -step)
        }
        forwardArrow.onClick = { [weak self] in
            self?.scroll(by: step)
        }
        scrollGeom = ScrollGeom(
            strip: strip,
            inset: inset,
            horizontal: horizontal,
            step: step,
            maxOffset: maxOffset,
            trailingAxis: trailingAxis
        )
    }

    /// Shifts bar offset and re-renders without forcing active follow.
    func scroll(by delta: CGFloat) {
        scrollOffset += delta
        render(followingActive: false)
    }

    /// Updates drag autoscroll state based on cursor position (#385).
    func updateDragAutoScroll(atGlobal cocoaPoint: CGPoint) {
        guard isPanelVisible, let geom = scrollGeom else {
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
        let hit = Self.arrowHit(
            at: local,
            strip: geom.strip,
            inset: geom.inset,
            trailingAxis: geom.trailingAxis,
            horizontal: geom.horizontal
        )
        let direction = scrollableDirection(hit, geom: geom)
        backArrow.setDragHover(direction == .back)
        forwardArrow.setDragHover(direction == .forward)
        setAutoScrollDirection(direction)
    }

    /// Cancels active autoscroll task and clears drag hovers.
    func cancelDragAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        autoScrollDirection = nil
        backArrow.setDragHover(false)
        forwardArrow.setDragHover(false)
    }

    private func scrollableDirection(
        _ hit: ScrollArrow?,
        geom: ScrollGeom
    ) -> ScrollArrow? {
        switch hit {
        case .back where scrollOffset > 0.5:
            return .back
        case .forward where geom.maxOffset - scrollOffset > 0.5:
            return .forward
        default:
            return nil
        }
    }

    private func setAutoScrollDirection(_ direction: ScrollArrow?) {
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
            backArrow.setDragHover(false)
            forwardArrow.setDragHover(false)
            return false
        }
        return true
    }
}

/// Seconds → nanoseconds for `Task.sleep`.
private func nanos(_ seconds: TimeInterval) -> UInt64 {
    UInt64(seconds * 1_000_000_000)
}
