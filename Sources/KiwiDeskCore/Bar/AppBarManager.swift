import AppKit

/// Manages per-display `AppBarOverlay` instances and event routing (#16,
/// #293).
@MainActor
public final class AppBarManager {
    /// Resolved bar configuration and geometry for a single display.
    public struct Bar {
        public let display: DisplayID
        public let space: SpaceID
        public let items: [AppBarOverlay.Item]
        public let activeIndex: Int?
        public let strip: CGRect
        /// The resolved style with absolute bar edge (#293).
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
    /// `KiwiCore.moveBarItem`.
    public var onMove: @MainActor (SpaceID, Int, Int) -> Void = {
        _,
        _,
        _ in
    }

    private var overlays: [DisplayID: AppBarOverlay] = [:]
    private var spaceOfDisplay: [DisplayID: SpaceID] = [:]
    /// The bars actually painted after `sync`'s filter — the one
    /// source for anything that must sit clear of a bar (#242).
    private var shownBars: [Bar] = []

    public init() {}

    /// Displays currently showing an app bar.
    public var shownDisplays: Set<DisplayID> {
        Set(spaceOfDisplay.keys)
    }

    /// Painted app bar strips across all displays (#242, QA 2026-07-19).
    public var shownStrips: [(space: SpaceID, strip: CGRect, edge: AppBarEdge)]
    {
        shownBars.map {
            (
                space: $0.space,
                strip: $0.strip,
                edge: $0.style.edge
            )
        }
    }

    /// True when a painted bar is currently rendering or
    /// announcing `id`'s title (#670, 2026-08-20). Deliberately
    /// NOT gated on `showsText` or the edge (#937): icon-only and
    /// vertical bars still build their accessibility label from
    /// the title, and an announced-stale title is as wrong as a
    /// drawn-stale one. A `count > 1` group draws its APP NAME,
    /// never a member's title, so a group is not a consumer.
    public func showsTitle(of id: WindowID) -> Bool {
        shownBars.contains { bar in
            bar.items.contains {
                $0.id == id && $0.count == 1
            }
        }
    }

    /// Painted app bar strips covering `space`.
    public func strips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        shownStrips
            .filter { $0.space == space }
            .map { (strip: $0.strip, edge: $0.edge) }
    }

    /// Synchronizes painted overlays with `bars`, retiring overlays for
    /// removed displays.
    public func sync(_ bars: [Bar]) {
        let valid = bars.filter {
            !$0.items.isEmpty
                && $0.strip.width >= 1 && $0.strip.height >= 1
        }
        shownBars = valid
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
        func overlayForTesting(
            _ display: DisplayID
        ) -> AppBarOverlay? {
            overlays[display]
        }

        /// Test seam: bars accepted by last `sync` (`BarTitleRefreshTests`).
        var shownBarsForTesting: [Bar] { shownBars }
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
