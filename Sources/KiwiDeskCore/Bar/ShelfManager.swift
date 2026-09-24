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
        let space: (overlay: SpaceBarOverlay, slot: CGRect)?
        let app: (overlay: AppBarOverlay, slot: CGRect)?
    }

    private var overlays: [DisplayID: ShelfOverlay] = [:]
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
            shelf.space?.overlay.onRendered = { [weak self] in
                self?.relayout(shelf.display)
            }
            shelf.app?.overlay.onRendered = { [weak self] in
                self?.relayout(shelf.display)
            }
            relayout(shelf.display)
        }
    }

    /// Re-lays one display's shelf from what its sections drew.
    func relayout(_ display: DisplayID) {
        guard let shelf = last[display] else { return }
        var sections: [ShelfOverlay.Section] = []
        if let space = shelf.space, space.overlay.isVisible {
            sections.append(
                .init(
                    view: space.overlay.root,
                    slot: space.slot,
                    plate: space.overlay.plateFrame
                )
            )
        }
        if let app = shelf.app, app.overlay.isVisible {
            sections.append(
                .init(
                    view: app.overlay.root,
                    slot: app.slot,
                    plate: app.overlay.plateFrame
                )
            )
        }
        let overlay = overlays[display] ?? ShelfOverlay()
        overlays[display] = overlay
        overlay.show(
            strip: shelf.strip,
            shelf: LiquidGlassGate.rendered(shelf.shelf),
            sections: sections
        )
    }

    #if DEBUG
        func overlayForTesting(_ display: DisplayID) -> ShelfOverlay? {
            overlays[display]
        }
    #endif
}
