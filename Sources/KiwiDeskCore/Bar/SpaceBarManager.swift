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
        public let strip: CGRect
        /// The resolved style; its `edge` is the stored
        /// absolute edge — single source, like the App Bar.
        public let style: SpaceBarStyle

        public init(
            display: DisplayID,
            items: [SpaceBarOverlay.Item],
            strip: CGRect,
            style: SpaceBarStyle
        ) {
            self.display = display
            self.items = items
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

    /// Every painted TOP strip as `(display, strip)`. Floats
    /// must clear a top Space Bar exactly like a top App Bar
    /// (#242) — read the painted strips, never re-derive.
    public var shownTopStrips:
        [(
            display: DisplayID, strip: CGRect
        )]
    {
        shownBars
            .filter { $0.style.edge == .top }
            .map { (display: $0.display, strip: $0.strip) }
    }

    /// The painted top strip on `display`, or nil when that
    /// display shows no top Space Bar.
    public func topStrip(
        forDisplay display: DisplayID
    ) -> CGRect? {
        shownTopStrips.first { $0.display == display }?.strip
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
                strip: bar.strip,
                style: bar.style
            )
        }
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
