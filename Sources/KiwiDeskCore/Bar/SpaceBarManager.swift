import AppKit

/// Space Bar overlay manager across displays (#293, `AppBarManager`).
@MainActor
public final class SpaceBarManager {
    /// One display's resolved bar configuration.
    public struct Bar {
        public let display: DisplayID
        public let items: [SpaceBarOverlay.Item]
        /// Trailing front-app segment app data.
        let frontApp: SpaceBarItemView.App?
        /// Window ID associated with the front-app segment
        /// (`showsTitle(of:)`).
        let frontWindow: WindowID?
        public let strip: CGRect
        public let style: SpaceBarStyle
        /// Mark indicator colors (#429, `StickyStyle`, `FloatingStyle`).
        let stateMarkColors: StateMarkColors

        init(
            display: DisplayID,
            items: [SpaceBarOverlay.Item],
            frontApp: SpaceBarItemView.App? = nil,
            frontWindow: WindowID? = nil,
            strip: CGRect,
            style: SpaceBarStyle,
            stateMarkColors: StateMarkColors
        ) {
            self.display = display
            self.items = items
            self.frontApp = frontApp
            self.frontWindow = frontWindow
            self.strip = strip
            self.style = style
            self.stateMarkColors = stateMarkColors
        }
    }

    /// Selection callback (`KiwiCore.focusSpace`).
    public var onSelectSpace: @MainActor (SpaceID) -> Void = {
        _ in
    }

    private var overlays: [DisplayID: SpaceBarOverlay] = [:]
    /// Active visible bars painted on screen.
    private var shownBars: [Bar] = []

    public init() {}

    /// Displays currently showing a bar.
    public var shownDisplays: Set<DisplayID> {
        Set(shownBars.map(\.display))
    }

    /// Painted strips with display and edge metadata (#242, QA 2026-07-19).
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

    /// Whether a painted bar's front segment presents title for `id`
    /// (review 2026-08-20).
    public func showsTitle(of id: WindowID) -> Bool {
        shownBars.contains { $0.frontWindow == id }
    }

    /// Synchronizes visible bar overlays across displays.
    public func sync(_ bars: [Bar]) {
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
                style: bar.style,
                stateMarkColors: bar.stateMarkColors
            )
        }
    }

    /// Hit-tests global screen point against space items (#372).
    public func spaceItem(atGlobal point: CGPoint) -> SpaceID? {
        for overlay in overlays.values {
            if let space = overlay.spaceItem(atGlobal: point) {
                return space
            }
        }
        return nil
    }

    /// Updates drag-hover highlight state across overlays.
    public func setDragHover(_ space: SpaceID?) {
        overlays.values.forEach { $0.setDragHover(space) }
    }

    /// Starts spring-load progress sweep on target space overlay.
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

    /// Clears drag hover and spring sweep visual indicators.
    public func clearDragFeedback() {
        overlays.values.forEach { $0.clearDragFeedback() }
    }

    /// Updates drag autoscroll cursor position across overlays (#385).
    public func updateDragAutoScroll(atGlobal point: CGPoint) {
        overlays.values.forEach {
            $0.updateDragAutoScroll(atGlobal: point)
        }
    }

    /// Cancels active drag autoscroll across all overlays.
    public func endDragAutoScroll() {
        overlays.values.forEach { $0.cancelDragAutoScroll() }
    }

    #if DEBUG
        /// Test seam: overlay backing a specific display.
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
