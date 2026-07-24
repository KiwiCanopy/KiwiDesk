import AppKit
import CoreGraphics
import Foundation

/// The live half of the drag pipeline (split from
/// `KiwiCore+Drag.swift` for the file ceiling; the drop
/// resolution stays there).
extension KiwiCore {
    /// Live feedback while a tiled window is dragged: a ghost
    /// outline over the window's own slot, a highlight over the
    /// slot a drop would swap with (settings toggle each visual
    /// individually), and the cross-display make-room debounce
    /// (#504) that moves the window's membership once the cursor
    /// dwells on another display.
    func handleDragMove(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) {
        // Pin the dragged window against `stashInactive` for the
        // gesture's life, so a Space Bar spring can't stash it
        // mid-drag (#372). Cleared at drop.
        tiler.dragExemptWindow = id
        // Feed the Space Bar drop machine the live cursor. While a
        // bar target is armed (hover + pending spring), suppress
        // the in-space ghost/drop-zone — the drag is heading off
        // this space, not swapping within it. The autoscroll runs
        // in parallel off the same cursor: a dwell over an arrow
        // zone scrolls hidden Spaces into reach (#385). The zones
        // are disjoint from item hit frames, so at most one of the
        // two arms for any given cursor position.
        let cursor = drag.cursorLocation()
        spaceBars.updateDragAutoScroll(atGlobal: cursor)
        spaceBarDrop.moved(id, cursor: cursor)
        if spaceBarDrop.isArmed {
            // A bar spring and a display crossing are competing
            // membership moves; the armed bar wins the dwell.
            dragCrossing.cancelPending(for: id)
            dragOverlay.hideAll()
            return
        }
        guard
            let space = activeSpace,
            space.mode != .floating,
            space.windows.contains(id),
            state.windows[id]?.isFloating == false
        else {
            dragCrossing.cancelPending(for: id)
            dragOverlay.hideAll()
            return
        }
        let slots = tiler.calculatedFrames(state: state)
        guard let slot = slots[id] else {
            dragCrossing.cancelPending(for: id)
            dragOverlay.hideAll()
            return
        }
        // Show the swap overlays only once the gesture is
        // clearly a MOVE — the window has translated with its
        // size held; anything else hides them.
        //
        // A resize is caught from its first real frame by facts
        // a magnitude test alone misses (it reads the sub-
        // threshold start of a pull, and a dip back near the
        // start size, as a move — flashing the ghost, #237):
        //  - the press began in the slot's edge band, where
        //    resize drags start (same signal isResizeGesture
        //    uses), AND the size has already changed — so an
        //    edge-grabbed move (drag near the top to swap) keeps
        //    its ghost while a resize hides with no flash;
        //  - the 10 pt magnitude test as the press-less
        //    fallback, measured against the START frame, never
        //    the slot: a window that can't shrink to its slot
        //    (min sizes, character grids) differs forever, which
        //    would call every plain move a resize.
        // The gesture's FIRST frame has no delta (start ==
        // frame) so it reads as neither; showing nothing there
        // avoids a one-frame ghost before the size delta lands.
        //
        // This gate is intentionally stricter than the resize-
        // vs-swap decision in handleDragEnd (plain isResize):
        // the preview is advisory and biases toward hiding to
        // kill the flash, so it may suppress a small edge resize
        // the drop still treats as a swap — harmless, since a
        // real move holds its size and never enters that band.
        // Effectiveness rides on the live mouse monitor; with no
        // recorded press (headless, tests) it falls back to the
        // 10 pt magnitude test — the pre-fix behavior.
        let pressNearEdge =
            mouse.press.map {
                MouseResize.nearEdge($0.location, of: slot)
            } ?? false
        let sizeChanged =
            abs(frame.width - start.width) > 0.5
            || abs(frame.height - start.height) > 0.5
        let movedOrigin =
            abs(frame.minX - start.minX) > 0.5
            || abs(frame.minY - start.minY) > 0.5
        let looksResize =
            (pressNearEdge && sizeChanged)
            || MouseResize.isResize(from: start, to: frame)
        // A gesture that already crossed displays (#504) is a
        // move for the rest of its life: macOS clamps a big
        // window's size as it lands on a smaller display, which
        // the magnitude test would read as a resize — hiding the
        // ghost the crossing just made room for (the live twin
        // of the #492 drop-ordering gotcha).
        let crossed = dragCrossing.hasCrossed(id)
        if (looksResize || !movedOrigin) && !crossed {
            if looksResize {
                // An edge pull near the display seam must never
                // dwell into a membership move.
                dragCrossing.cancelPending(for: id)
            }
            dragOverlay.hideAll()
            return
        }
        // A clear move: arm / keep the cross-display dwell.
        updateDragCrossing(id, cursor: cursor)
        let settings = tiler.settings
        guard
            settings.dragGhost.enabled
                || settings.dragDropZone.enabled
        else {
            dragOverlay.hideAll()
            return
        }
        if settings.dragGhost.enabled {
            dragOverlay.showGhost(
                at: slot,
                style: settings.dragGhost,
                cornerRadius: settings.dragCornerRadius
            )
        }
        // Target the slot under the CURSOR, not the dragged
        // frame's center: the drop-zone must reach the
        // destination display the instant the pointer does,
        // even while a big window's center trails behind on the
        // origin display (#492). `cursor` is Cocoa (bottom-left);
        // slots are AX (top-left), so flip it.
        let target = DragTarget.swapTarget(
            of: id,
            at: GeometryUtils.axPoint(cursor),
            slots: slots
        )
        // Suppress the highlight over a cross-display track dest
        // (files by rule, not the slot); see `dropZoneTarget` (#492).
        let honestTarget = dropZoneTarget(target, from: space)
        if settings.dragDropZone.enabled,
            let honestTarget,
            let targetSlot = slots[honestTarget]
        {
            dragOverlay.showDropZone(
                at: targetSlot,
                style: settings.dragDropZone,
                cornerRadius: settings.dragCornerRadius
            )
        } else {
            dragOverlay.hideDropZone()
        }
    }
}
