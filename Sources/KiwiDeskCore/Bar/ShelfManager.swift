import AppKit

/// One `ShelfOverlay` per display (#1517): places the sections the
/// two bar managers render and draws the plate they share. Synced
/// after both bars in `updateBars`, and re-laid whenever a section
/// renders on its own (a manual scroll, a drag) so the plate never
/// trails what the section drew.
@MainActor
final class ShelfManager {
    /// One display's shelf: its strip and each shown section's
    /// overlay and slot, in AX coordinates.
    struct Shelf {
        let display: DisplayID
        let strip: CGRect
        let shelf: KiwiShelf
        /// The sections shown here; each is placed at the slot it
        /// drew into (`shownStrip`), so the two cannot disagree.
        let space: SpaceBarOverlay?
        let app: AppBarOverlay?
        /// Set while the shelf is full, so the divider drags.
        var divider: ShelfArrangement.Divider? = nil
    }

    /// A Space Bar minimum the divider reached (`committed` on
    /// release) — wired once, to the settings-apply door.
    var onMinimum: (_ percent: CGFloat, _ committed: Bool) -> Void = {
        _,
        _ in
    }

    private var overlays: [DisplayID: ShelfOverlay] = [:]
    /// Set while `updateBars` syncs the two bars: their renders
    /// would otherwise re-lay the shelf against the previous plan
    /// before `sync` hands it the new one.
    private(set) var holdsRelayout = false

    /// Runs `body` with relayout held, released however it exits.
    func holdingRelayout(_ body: () -> Void) {
        holdsRelayout = true
        defer { holdsRelayout = false }
        body()
    }
    private var last: [DisplayID: Shelf] = [:]

    /// Shows `shelves`, retiring the shelf of any display absent.
    func sync(_ shelves: [Shelf]) {
        let wanted = Set(shelves.map(\.display))
        for (id, overlay) in overlays where !wanted.contains(id) {
            overlay.hide()
            overlays[id] = nil
            last[id] = nil
        }
        for shelf in shelves {
            last[shelf.display] = shelf
            shelf.space?.onRendered = { [weak self] in
                self?.relayout(shelf.display)
            }
            shelf.app?.onRendered = { [weak self] in
                self?.relayout(shelf.display)
            }
            relayout(shelf.display)
        }
    }

    /// Re-lays one display's shelf from what its sections drew.
    func relayout(_ display: DisplayID) {
        guard !holdsRelayout, let shelf = last[display] else { return }
        var sections: [ShelfOverlay.Section] = []
        if let space = shelf.space, space.isVisible,
            let slot = space.shownStrip
        {
            sections.append(
                .init(view: space.root, slot: slot, plate: space.plateFrame)
            )
        }
        if let app = shelf.app, app.isVisible, let slot = app.shownStrip {
            sections.append(
                .init(view: app.root, slot: slot, plate: app.plateFrame)
            )
        }
        let overlay = overlays[display] ?? ShelfOverlay()
        overlays[display] = overlay
        overlay.handle.onMinimum = { [weak self] percent, committed in
            self?.onMinimum(percent, committed)
        }
        overlay.handle.onReset = { [weak self] in
            self?.onMinimum(KiwiShelf.resetMinimum, true)
        }
        overlay.show(
            strip: shelf.strip,
            shelf: LiquidGlassGate.rendered(shelf.shelf),
            sections: sections,
            divider: shelf.divider
        )
        // Placement moves views under a resting pointer and AppKit
        // sends no exit for it: every hover is re-read here, the
        // one point where both sections and the panel are placed.
        shelf.space?.syncHoverToPointer()
        shelf.app?.syncHoverToPointer()
        overlay.handle.syncHoverToPointer()
    }

    #if DEBUG
        func overlayForTesting(_ display: DisplayID) -> ShelfOverlay? {
            overlays[display]
        }
    #endif
}
