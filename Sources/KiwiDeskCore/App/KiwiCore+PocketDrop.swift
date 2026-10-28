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
        let hovered = pointerOverPocketPlate() && pocketNamedRefusal(id) == nil
        if pocketPlate.dragging != id || pocketPlate.dropHovered != hovered {
            if pocketPlate.dragging != id {
                // Held on one screen for the gesture, so the target
                // never jumps while it is aimed at.
                pocketPlate.dragDisplay = state.pocketHomeDisplay
            }
            pocketPlate.dragging = id
            pocketPlate.dropHovered = hovered
            updatePocketPlate()
        }
        return hovered
    }

    /// Whether the gesture of `id` is a move the plate takes part in,
    /// latched once it reads as a resize: the origin moved and the
    /// size held past `MouseResize`'s threshold — save the shrink
    /// macOS clamps on a crossing, which stays a move (#504).
    private func pocketMoveVerdict(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) -> Bool {
        guard pocketPlate.resizing != id else { return false }
        let grew =
            frame.width > start.width + 0.5
            || frame.height > start.height + 0.5
        let resized =
            grew
            || (MouseResize.isResize(from: start, to: frame)
                && !dragCrossing.hasCrossed(id))
        if resized {
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
            live && pocketPlate.dragging == id && pointerOverPocketPlate()
        let lit = over && pocketPlate.dropHovered
        endPocketDrag()
        if over, !lit, pocketNamedRefusal(id) == .taken {
            _ = refuseSecondPocketWindow(id)
        }
        guard lit else { return false }
        // An out window comes out next where it was before the drag,
        // never on the plate it was dropped on.
        pocketPlate.dropStart = (id, start, frame)
        defer { pocketPlate.dropStart = nil }
        let response = execute(
            "pocket",
            args: [.number(Double(id.raw))]
        )
        if !response.isSuccess { retile() }
        return true
    }

    /// Drops the plate's drag state; a cancelled drag ends here.
    func endPocketDrag() {
        guard pocketPlate.dragging != nil else { return }
        pocketPlate.dragging = nil
        pocketPlate.dropHovered = false
        pocketPlate.dragDisplay = nil
        updatePocketPlate()
    }

    /// The gesture of `id` is over, normally or not.
    func finishPocketGesture(_ id: WindowID) {
        if pocketPlate.resizing == id { pocketPlate.resizing = nil }
        if pocketPlate.dragging == id { endPocketDrag() }
    }

    /// Whether the pointer is over the plate as drawn (Cocoa points).
    func pointerOverPocketPlate() -> Bool {
        guard let frame = pocketPlate.shown?.frame else { return false }
        return frame.contains(drag.cursorLocation())
    }
}
