import AppKit

/// One app bar per display (#16). Owns an `AppBarOverlay` keyed by
/// `DisplayID`, so several monitors can each show the bar of the
/// space currently visible on them at the same time. The driver
/// (`KiwiCore.updateAppBar`) computes the bars; this manager just
/// creates, shows, and retires overlays and routes their callbacks.
@MainActor
public final class AppBarManager {
    /// One display's resolved bar. `space` rides along so a drag
    /// on that bar reorders the right space (not the global
    /// active one) — displays other than the focused one host
    /// their own space's bar.
    public struct Bar {
        public let display: DisplayID
        public let space: SpaceID
        public let items: [AppBarOverlay.Item]
        public let activeIndex: Int?
        public let strip: CGRect
        public let style: AppBarStyle

        public init(
            display: DisplayID,
            space: SpaceID,
            items: [AppBarOverlay.Item],
            activeIndex: Int?,
            strip: CGRect,
            style: AppBarStyle
        ) {
            self.display = display
            self.space = space
            self.items = items
            self.activeIndex = activeIndex
            self.strip = strip
            self.style = style
        }
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusWindow`.
    public var onSelect: @MainActor (WindowID) -> Void = { _ in }
    /// Drag reorder hook (space, from slot, to slot); wired to
    /// `KiwiCore.moveBarItem`. The space is the one whose bar the
    /// dragged overlay is currently showing.
    public var onMove: @MainActor (SpaceID, Int, Int) -> Void = {
        _,
        _,
        _ in
    }

    private var overlays: [DisplayID: AppBarOverlay] = [:]
    private var spaceOfDisplay: [DisplayID: SpaceID] = [:]

    public init() {}

    /// Displays currently showing a bar; the manager's contract
    /// surface for tests and diagnostics.
    public var shownDisplays: Set<DisplayID> {
        Set(spaceOfDisplay.keys)
    }

    /// Shows exactly `bars` — one per display — and retires the
    /// overlays of any display no longer in the set (passing an
    /// empty array retires them all). Retiring releases the
    /// panel, so a display that never returns leaves nothing
    /// behind.
    public func sync(_ bars: [Bar]) {
        // A bar whose strip/items can't render is treated as
        // absent — AppBarOverlay.show would hide it anyway — so
        // its display retires instead of keeping a stale panel,
        // and the "shown" bookkeeping (and thus onMove routing)
        // never claims a display whose panel is hidden.
        let valid = bars.filter {
            !$0.items.isEmpty
                && $0.strip.width >= 1 && $0.strip.height >= 1
        }
        let wanted = Set(valid.map(\.display))
        for (id, overlay) in overlays where !wanted.contains(id) {
            overlay.hide()
            overlays[id] = nil
            spaceOfDisplay[id] = nil
        }
        for bar in valid {
            let overlay = overlay(for: bar.display)
            spaceOfDisplay[bar.display] = bar.space
            overlay.show(
                items: bar.items,
                activeIndex: bar.activeIndex,
                strip: bar.strip,
                style: bar.style
            )
        }
    }

    #if DEBUG
        /// Test seam: the overlay currently backing a display.
        func overlayForTesting(
            _ display: DisplayID
        ) -> AppBarOverlay? {
            overlays[display]
        }
    #endif

    private func overlay(for display: DisplayID) -> AppBarOverlay {
        if let existing = overlays[display] { return existing }
        let overlay = AppBarOverlay()
        overlay.onSelect = { [weak self] id in
            self?.onSelect(id)
        }
        overlay.onMove = { [weak self] from, to in
            guard let self,
                let space = self.spaceOfDisplay[display]
            else { return }
            self.onMove(space, from, to)
        }
        overlays[display] = overlay
        return overlay
    }
}
