import AppKit

/// The pocket plate as a drop target (#2678): every window drag shows
/// it, a window over it that `pocket` would take lights it, and the
/// drop pockets that window through `pocket` naming it — ⌃⌥P's play
/// under the same switch. A window the pocket would refuse lights
/// nothing, and its drop goes back where it was with the refusal.
extension KiwiCore {
    /// The drag of `id` moved from `start` to `frame`: shows the
    /// plate and lights it under a window it would take. True while
    /// the pointer is over it, so the drag's own preview stands
    /// down. A resize keeps no size, and is no drop.
    func pocketDragMoved(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) -> Bool {
        guard Self.isMove(from: start, to: frame) else { return false }
        let over = pointerOverPocketPlate()
        let hovered = over && pocketNamedRefusal(id) == nil
        if pocketPlate.dragging != id || pocketPlate.dropHovered != hovered {
            pocketPlate.dragging = id
            pocketPlate.dropHovered = hovered
            updatePocketPlate()
        }
        return over
    }

    /// The drag of `id` ended: true where it dropped on the plate,
    /// which then decided it. `live` is false for a late gesture,
    /// whose pointer has moved on since its release (#1798).
    func pocketDragEnded(_ id: WindowID, live: Bool) -> Bool {
        // Only a move showed the plate; a resize ending over it is none.
        let over =
            live && pocketPlate.dragging == id && pointerOverPocketPlate()
        endPocketDrag()
        guard over else { return false }
        let response = execute(
            "pocket",
            args: [.number(Double(id.raw))]
        )
        // A refused drop goes back where it was.
        if !response.isSuccess { retile() }
        return true
    }

    /// Drops the plate's drag state; a cancelled drag ends here.
    func endPocketDrag() {
        guard pocketPlate.dragging != nil else { return }
        pocketPlate.dragging = nil
        pocketPlate.dropHovered = false
        updatePocketPlate()
    }

    /// Whether a gesture from `start` to `frame` moves the window
    /// rather than resizing it.
    static func isMove(from start: CGRect, to frame: CGRect) -> Bool {
        abs(start.width - frame.width) < 1
            && abs(start.height - frame.height) < 1
    }

    /// Whether the pointer is over the plate as drawn (Cocoa points).
    func pointerOverPocketPlate() -> Bool {
        guard let frame = pocketPlate.shown?.frame else { return false }
        return frame.contains(drag.cursorLocation())
    }
}
