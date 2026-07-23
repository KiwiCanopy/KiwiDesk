import AppKit

/// Whole-bar overflow for the Space Bar (#385): the scroll arrows,
/// their layout and click handling, and the drag autoscroll that
/// lets a window be dropped onto a Space scrolled off the strip.
///
/// The arrow zones are chrome that structurally excludes every
/// item's hit frame (see `recordHitFrames`), so a drag cursor is
/// over an arrow XOR over a Space item, never both. The autoscroll
/// (this file) and the drop-spring (`SpaceBarDropCoordinator`)
/// therefore govern disjoint zones and never contend — no shared
/// dwell state, no coordination flag.
extension SpaceBarOverlay {
    /// Scroll geometry cached each render for the autoscroll path.
    struct ScrollGeom {
        let strip: CGRect
        /// Arrow-zone inset (> 0 only while overflowing).
        let inset: CGFloat
        let horizontal: Bool
        /// Distance one click / autoscroll tick shifts the bar.
        let step: CGFloat
        /// The largest valid scroll offset (`total − viewport`).
        let maxOffset: CGFloat
        /// The Spaces region's trailing edge along the axis (#409):
        /// the strip length, or `strip − front band` while the front
        /// segment is pinned. The forward arrow sits one zone inside
        /// it, and `arrowHit` bounds the forward zone by it.
        let trailingAxis: CGFloat
    }

    /// Quiet dwell over an arrow before the first autoscroll tick,
    /// then the tick interval. Proposed defaults (#385) — worth a
    /// feel-test pass, like #372's spring dwell, before treated as
    /// settled; not user-configurable (no new knob).
    nonisolated static let autoScrollInitialDelay: TimeInterval =
        0.2
    nonisolated static let autoScrollInterval: TimeInterval = 0.3

    // MARK: - Arrow layout

    /// Places the two scroll arrows over the strip's ends, shown
    /// only toward hidden items, and caches the scroll geometry.
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
        // The forward arrow sits at the Spaces region's trailing
        // edge — the strip rim, or one front band in while the front
        // segment is pinned there (#409).
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

    /// Shifts the bar by `delta` and re-renders without following
    /// the active Space, so a manual scroll isn't snapped back.
    /// `render` re-clamps the offset to the valid range.
    func scroll(by delta: CGFloat) {
        scrollOffset += delta
        render(followingActive: false)
    }

    // MARK: - Drag autoscroll

    /// Feeds the live drag cursor (Cocoa, bottom-left global) so a
    /// dwell over an arrow zone autoscrolls the bar toward the
    /// hidden Spaces. Off the strip or off the arrows, stops any
    /// running autoscroll. Drives the arrow's synthetic hover too
    /// — a foreign AX drag delivers no `mouseEntered` (#385).
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
        // Only a direction that still has hidden items counts —
        // the matching arrow is visible exactly then.
        let direction = scrollableDirection(hit, geom: geom)
        backArrow.setDragHover(direction == .back)
        forwardArrow.setDragHover(direction == .forward)
        setAutoScrollDirection(direction)
    }

    /// Stops any autoscroll and clears the arrows' drag hover.
    func cancelDragAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        autoScrollDirection = nil
        backArrow.setDragHover(false)
        forwardArrow.setDragHover(false)
    }

    /// The scroll direction the hit implies, but only if the bar
    /// can still move that way; nil otherwise.
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
        // Dwell, then tick every interval until the direction is
        // cleared (cursor left the arrow), the drag ends (task
        // cancelled), or the bar can't scroll further. Mirrors the
        // drop coordinator's `dwellTask`.
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

    /// One autoscroll step; returns whether to keep ticking. Stops
    /// (returns false) once the bar is clamped at the far end —
    /// the arrow it was hovering has now hidden.
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
