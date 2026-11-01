import AppKit

/// The pocket plate as a drop target (#2678): every window drag shows
/// it, a window over it that `pocket` would take lights it, and the
/// drop pockets that window through `pocket` naming it — ⌃⌥P's play
/// under the same switch. A window the pocket would refuse lights
/// nothing, and its drop goes back where it was with the refusal.
extension KiwiCore {
    /// The drag of `id` moved from `start` to `frame`: shows the
    /// plate and lights it under a window it would take. True while
    /// it is lit, so the drag's own preview stands down; a window
    /// it would refuse keeps its preview. A resize keeps no size,
    /// and is no drop.
    func pocketDragMoved(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) -> Bool {
        guard pocketMoveVerdict(id, start: start, frame: frame) else {
            return false
        }
        if pocketPlate.dragging != id {
            pocketPlate.dragging = id
            pocketPlate.dropHovered = nil
            // A drag stands the pocket, its place the bar pass's.
            updateBars()
            // A drag that starts on the pocket, a title bar under it,
            // arms it only once the pointer has left it (#2793).
            pocketPlate.armed = false
        }
        let under = pocketUnderPointer()
        if under == nil { pocketPlate.armed = true }
        let hovered =
            pocketPlate.armed && pocketNamedRefusal(id) == nil ? under : nil
        if pocketPlate.dropHovered != hovered {
            pocketPlate.dropHovered = hovered
            updatePocketPlate()
        }
        return hovered != nil
    }

    /// Whether the gesture of `id` is a move the plate takes part in,
    /// latched off at the first size change, so an edge pull never
    /// shows it — save the shrink macOS clamps on a crossing, which
    /// stays a move (#504). A clamp ahead of the crossing latches it
    /// off too, the trade for never flashing on a pull.
    private func pocketMoveVerdict(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) -> Bool {
        guard pocketPlate.resizing != id else { return false }
        let resized =
            abs(frame.width - start.width) > 0.5
            || abs(frame.height - start.height) > 0.5
        if resized, !dragCrossing.hasCrossed(id) {
            pocketPlate.resizing = id
            endPocketDrag()
            return false
        }
        // A first frame without a delta decides nothing yet.
        return abs(frame.minX - start.minX) > 0.5
            || abs(frame.minY - start.minY) > 0.5
    }

    /// The drag of `id` from `start` to `frame` ended: true where
    /// the lit plate took the drop. A refused window over it is
    /// told why and drops as it would anywhere else. `live` is false
    /// for a late gesture, whose pointer has moved on since its
    /// release (#1798).
    func pocketDragEnded(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect,
        live: Bool
    ) -> Bool {
        let over =
            live && pocketPlate.dragging == id && pocketPlate.armed
            && pocketUnderPointer() != nil
        let lit = over && pocketPlate.dropHovered != nil
        guard lit else {
            endPocketDrag()
            switch over ? pocketNamedRefusal(id) : nil {
            case .taken?: _ = refuseSecondPocketWindow(id)
            case .keyed(let app)?: _ = refuseKeyedPocketWindow(id, app: app)
            default: break
            }
            return false
        }
        // An out window comes out next where it was before the drag,
        // never on the plate it was dropped on.
        pocketPlate.dropStart = (id, start, frame)
        defer { pocketPlate.dropStart = nil }
        // The put-in's play holds the pocket before the drag lets it
        // go, so a sliding pocket never leaves between them (#2793).
        let response = execute(
            "pocket",
            args: [.number(Double(id.raw))]
        )
        endPocketDrag()
        // Refused at the drop after all: the ordinary drop takes it.
        return response.isSuccess
    }

    /// Whether a window MOVE is in flight: the plate's move verdict,
    /// asked of the live gesture too, since a cancel straight on the
    /// coordinator skips the plate's clear. The bar reveal's one
    /// answer (#2795).
    var windowMoveInFlight: Bool {
        pocketPlate.dragging.map { drag.hasGesture($0) } == true
    }

    /// Drops the plate's drag state; a cancelled drag ends here.
    func endPocketDrag() {
        guard pocketPlate.dragging != nil else { return }
        pocketPlate.dragging = nil
        pocketPlate.dropHovered = nil
        pocketPlate.armed = false
        updateBars()
    }

    /// The gesture of `id` is over, normally or not.
    func finishPocketGesture(_ id: WindowID) {
        if pocketPlate.resizing == id { pocketPlate.resizing = nil }
        if pocketPlate.dragging == id { endPocketDrag() }
    }

    /// The display whose pocket, as drawn, the pointer is over
    /// (Cocoa points), nil where none.
    func pocketUnderPointer() -> DisplayID? {
        let cursor = drag.cursorLocation()
        return pocketPlate.specs.values.first {
            $0.frame.contains(cursor)
        }?.display
    }
}
