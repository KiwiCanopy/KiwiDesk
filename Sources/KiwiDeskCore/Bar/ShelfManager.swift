import AppKit

/// One `ShelfOverlay` per display and edge (#1517, #1731): one
/// while the bars share an edge, placing both sections on the one
/// plate they share, and one per bar while they are split. Synced
/// after both bars in `updateBars`, and re-laid whenever a section
/// renders on its own (a manual scroll, a drag) so the plate never
/// trails what the section drew.
@MainActor
final class ShelfManager {
    /// One shelf: its display, its edge, its strip and each shown
    /// section's overlay and slot, in AX coordinates.
    struct Shelf {
        let display: DisplayID
        let edge: AppBarEdge
        let strip: CGRect
        let shelf: KiwiShelf
        /// `border.sheen` (#1644), the plate border's ramp.
        let sheen: CGFloat
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

    /// The WindowServer's normal-layer windows, front to back —
    /// which window a screen SHOWS in front, read by the
    /// presentation stand-down (#1787). Pinned to `[]` by both
    /// `makeTestCore` twins.
    var frontWindowFrames: @MainActor () -> [CGRect] = {
        let own = getpid()
        // KiwiDesk's chrome is never a presentation, and a moving
        // ring's panel spans its screen (#1937).
        return FloatDetection.frontToBackNormalFrames { pid, number in
            pid == own && EventLoop.isOwnChrome(number: number)
        }
    }

    /// Which shelf an overlay draws: a display's, on one edge.
    struct Key: Hashable {
        let display: DisplayID
        let edge: AppBarEdge
    }

    private var overlays: [Key: ShelfOverlay] = [:]
    /// The bars' context menus (#1518) — the one instance; Core
    /// sets its rows and hands it to both bar managers.
    let contextMenus = BarContextMenus()
    /// The bars' one hover peek (#1946); Core sets its content and
    /// hands it to both bar managers.
    let peek = BarPeek()
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
    private var last: [Key: Shelf] = [:]

    /// Shows `shelves`, fading out every shelf absent from them —
    /// a display's second one included, once its bars re-fuse —
    /// and retiring it once it has left (#1838).
    func sync(_ shelves: [Shelf]) {
        let wanted = Set(shelves.map(Self.key))
        for key in last.keys where !wanted.contains(key) {
            last[key] = nil
        }
        for (key, overlay) in overlays where !wanted.contains(key) {
            overlay.hide(animated: true)
        }
        for shelf in shelves {
            let key = Self.key(shelf)
            last[key] = shelf
            shelf.space?.onRendered = { [weak self] in
                self?.relayout(key)
            }
            shelf.app?.onRendered = { [weak self] in
                self?.relayout(key)
            }
            relayout(key)
        }
    }

    private static func key(_ shelf: Shelf) -> Key {
        Key(display: shelf.display, edge: shelf.edge)
    }

    /// Re-lays one shelf from what its sections drew.
    func relayout(_ key: Key) {
        guard !holdsRelayout, let shelf = last[key] else { return }
        var sections: [ShelfOverlay.Section] = []
        if let space = shelf.space, space.isVisible,
            let slot = space.shownStrip
        {
            sections.append(
                .init(
                    view: space.root,
                    slot: slot,
                    plate: space.plateFrame,
                    content: space.contentFrame
                )
            )
        }
        if let app = shelf.app, app.isVisible, let slot = app.shownStrip {
            sections.append(
                .init(
                    view: app.root,
                    slot: slot,
                    plate: app.plateFrame,
                    content: app.contentFrame
                )
            )
        }
        let overlay = overlays[key] ?? ShelfOverlay()
        overlays[key] = overlay
        overlay.onLeft = { [weak self] in self?.retire(key) }
        overlay.contextMenus = contextMenus
        overlay.handle.onMinimum = { [weak self] percent, committed in
            self?.onMinimum(percent, committed)
        }
        overlay.handle.onReset = { [weak self] in
            self?.onMinimum(KiwiShelf.resetMinimum, true)
        }
        overlay.show(
            strip: shelf.strip,
            edge: shelf.edge,
            shelf: LiquidGlassGate.rendered(shelf.shelf),
            sheen: shelf.sheen,
            sections: sections,
            divider: shelf.divider
        )
        // Placement moves views under a resting pointer and AppKit
        // sends no exit for it: every hover is re-read here, the
        // one point where both sections and the panel are placed.
        shelf.space?.syncHoverToPointer()
        shelf.app?.syncHoverToPointer()
        overlay.handle.syncHoverToPointer()
        // The peek's item may have moved under it, or left.
        peek.syncToAnchor()
    }

    /// The displays with a shelf still fading out: a bar manager
    /// spares their overlays, whose roots that fade still draws
    /// (#1838).
    var leavingDisplays: Set<DisplayID> {
        Set(overlays.filter { $0.value.isLeaving }.map(\.key.display))
    }

    /// Drops a shelf that has left the screen, unless a plan wants
    /// it again meanwhile.
    private func retire(_ key: Key) {
        guard last[key] == nil else { return }
        overlays[key] = nil
    }

    #if DEBUG
        /// The display's shelf on `edge`, or its one shelf when
        /// `edge` is nil and it has exactly one.
        func overlayForTesting(
            _ display: DisplayID,
            edge: AppBarEdge? = nil
        ) -> ShelfOverlay? {
            if let edge {
                return overlays[Key(display: display, edge: edge)]
            }
            let mine = overlays.filter { $0.key.display == display }
            return mine.count == 1 ? mine.first?.value : nil
        }
    #endif
}
