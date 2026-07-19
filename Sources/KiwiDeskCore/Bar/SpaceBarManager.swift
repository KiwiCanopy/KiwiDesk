import AppKit

/// One Space Bar per display (#293). Owns a `SpaceBarOverlay`
/// keyed by `DisplayID`; the driver (`KiwiCore.updateSpaceBar`)
/// computes the bars, this manager creates, shows, and retires
/// overlays and routes their click callbacks — the same shape as
/// `AppBarManager`.
@MainActor
public final class SpaceBarManager {
    /// One display's resolved bar.
    public struct Bar {
        public let display: DisplayID
        public let items: [SpaceBarOverlay.Item]
        /// The trailing front-app segment's app; nil while the
        /// toggle is off or nothing is focused.
        let frontApp: SpaceBarItemView.App?
        public let strip: CGRect
        /// The resolved style; its `edge` is the stored
        /// absolute edge — single source, like the App Bar.
        public let style: SpaceBarStyle

        init(
            display: DisplayID,
            items: [SpaceBarOverlay.Item],
            frontApp: SpaceBarItemView.App? = nil,
            strip: CGRect,
            style: SpaceBarStyle
        ) {
            self.display = display
            self.items = items
            self.frontApp = frontApp
            self.strip = strip
            self.style = style
        }
    }

    /// Click hook; wired to `KiwiCore.focusSpace`.
    public var onSelectSpace: @MainActor (SpaceID) -> Void = {
        _ in
    }

    private var overlays: [DisplayID: SpaceBarOverlay] = [:]
    /// The bars actually painted — the single source for
    /// anything that must sit clear of one (the #242 float
    /// clamp reads the top strips).
    private var shownBars: [Bar] = []

    public init() {}

    /// Displays currently showing a bar.
    public var shownDisplays: Set<DisplayID> {
        Set(shownBars.map(\.display))
    }

    /// Every painted strip as `(display, strip, edge)`. Floats
    /// must clear a Space Bar exactly like an App Bar (#242,
    /// all four edges since QA 2026-07-19) — read the painted
    /// strips, never re-derive.
    public var shownStrips:
        [(
            display: DisplayID, strip: CGRect,
            edge: AppBarEdge
        )]
    {
        shownBars.map {
            (
                display: $0.display,
                strip: $0.strip,
                edge: $0.style.edge
            )
        }
    }

    /// Shows exactly `bars` — one per display — and retires the
    /// overlays of any display no longer in the set.
    public func sync(_ bars: [Bar]) {
        // This filter, not the overlay's identical guard, is
        // the one `shownTopStrips` — and thus the float clamp —
        // depends on: never "simplify" it away.
        let valid = bars.filter {
            !$0.items.isEmpty
                && $0.strip.width >= 1 && $0.strip.height >= 1
        }
        shownBars = valid
        let wanted = Set(valid.map(\.display))
        for (id, overlay) in overlays
        where !wanted.contains(id) {
            overlay.hide()
            overlays[id] = nil
        }
        for bar in valid {
            overlay(for: bar.display).show(
                items: bar.items,
                frontApp: bar.frontApp,
                strip: bar.strip,
                style: bar.style
            )
        }
    }

    // MARK: - Drag-drop routing (#372)

    /// The Space whose item contains a global (Cocoa) screen
    /// point, across every painted bar; nil when the point is on
    /// no bar. Point-based hit test — see `SpaceBarOverlay`.
    public func spaceItem(atGlobal point: CGPoint) -> SpaceID? {
        for overlay in overlays.values {
            if let space = overlay.spaceItem(atGlobal: point) {
                return space
            }
        }
        return nil
    }

    /// Tints `space`'s item with the synthetic drag-hover and
    /// clears every other bar's items; nil clears all.
    public func setDragHover(_ space: SpaceID?) {
        overlays.values.forEach { $0.setDragHover(space) }
    }

    /// Starts the pending-spring sweep on `space`'s item — empty
    /// for `delay`, then filling over `duration`.
    public func beginSpringSweep(
        on space: SpaceID,
        duration: TimeInterval,
        delay: TimeInterval
    ) {
        overlays.values.forEach {
            $0.beginSpringSweep(
                on: space,
                duration: duration,
                delay: delay
            )
        }
    }

    /// Clears every hover tint and pending sweep across all bars.
    public func clearDragFeedback() {
        overlays.values.forEach { $0.clearDragFeedback() }
    }

    /// Feeds the live drag cursor to every bar so a dwell over a
    /// scroll-arrow zone autoscrolls that bar toward its hidden
    /// Spaces (#385), letting a window reach an off-screen Space.
    public func updateDragAutoScroll(atGlobal point: CGPoint) {
        overlays.values.forEach {
            $0.updateDragAutoScroll(atGlobal: point)
        }
    }

    /// Stops any drag autoscroll across all bars — the drag ended
    /// or was abandoned.
    public func endDragAutoScroll() {
        overlays.values.forEach { $0.cancelDragAutoScroll() }
    }

    #if DEBUG
        /// Test seam: the overlay currently backing a display.
        func overlayForTesting(
            _ display: DisplayID
        ) -> SpaceBarOverlay? {
            overlays[display]
        }
    #endif

    private func overlay(
        for display: DisplayID
    ) -> SpaceBarOverlay {
        if let existing = overlays[display] { return existing }
        let overlay = SpaceBarOverlay()
        overlay.onSelect = { [weak self] space in
            self?.onSelectSpace(space)
        }
        overlays[display] = overlay
        return overlay
    }
}
