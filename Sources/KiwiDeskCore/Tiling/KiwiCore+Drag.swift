import AppKit
import CoreGraphics
import Foundation

/// The drop-target rule, shared by the live preview and the
/// final drop so the highlight can never disagree with what
/// the drop does: a drag targets the slot that contains the
/// dragged frame's center.
enum DragTarget {
    static func swapTarget(
        of id: WindowID,
        frame: CGRect,
        slots: [WindowID: CGRect]
    ) -> WindowID? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let hits = slots.filter { entry in
            entry.key != id && entry.value.contains(center)
        }
        // Slots can overlap (stack overflow cascade). The hit
        // slot with the lowest top edge is the one visually
        // under the point: cascade windows sit progressively
        // lower and are raised on top of the previous ones,
        // so each slot's visible part is the strip between
        // its top edge and the next slot's. Ties (identical
        // slots) break by id, never by dictionary order.
        return hits.max { a, b in
            (a.value.minY, a.key.raw)
                < (b.value.minY, b.key.raw)
        }?.key
    }
}

/// Drop resolution for user window drags and resizes.
extension KiwiCore {
    /// Connects the drag coordinator's callbacks (once, from
    /// init).
    func wireDrag() {
        drag.isAnimating = { [weak self] id in
            guard let self else { return false }
            // Covers in-flight animations AND the trailing AX
            // echoes of frames we already applied: those
            // arrive after the animation settles and must not
            // read as user drags.
            return self.tiler.animation.isAnimating(window: id)
                || self.tiler.didRecentlySetFrame(id)
        }
        drag.onDragMove = { [weak self] id, start, frame in
            self?.handleDragMove(id, start: start, frame: frame)
        }
        drag.onDragEnd = { [weak self] id, start, frame in
            self?.handleDragEnd(id, start: start, frame: frame)
        }
        drag.isMousePressed = {
            NSEvent.pressedMouseButtons & 1 == 1
        }
    }

    /// Live feedback while a tiled window is dragged: a ghost
    /// outline over the window's own slot and a highlight
    /// over the slot a drop would swap with (settings toggle
    /// each visual individually).
    func handleDragMove(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) {
        let settings = tiler.settings
        guard
            settings.dragGhost.enabled
                || settings.dragDropZone.enabled,
            let space = activeSpace,
            space.mode != .floating,
            space.windows.contains(id),
            state.windows[id]?.isFloating == false
        else {
            dragOverlay.hideAll()
            return
        }
        let slots = tiler.calculatedFrames(state: state)
        guard let slot = slots[id] else {
            dragOverlay.hideAll()
            return
        }
        // A resize gesture adjusts the layout in place; slot
        // previews would only mislead. Compared against the
        // gesture's START frame, never the slot: a window
        // that can't shrink to its slot (min sizes, character
        // grids) differs from it permanently, which would
        // turn every plain move into a "resize".
        if MouseResize.isResize(from: start, to: frame) {
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
        let target = DragTarget.swapTarget(
            of: id,
            frame: frame,
            slots: slots
        )
        if settings.dragDropZone.enabled,
            let target,
            let targetSlot = slots[target]
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

    /// Drop over another window's layout slot: the two windows
    /// swap positions and everything readjusts. Drop anywhere
    /// else: the window snaps back to its own slot. A drop
    /// that changed the window's SIZE during the gesture is a
    /// resize gesture and adjusts the layout instead (see
    /// handleResizeEnd). Move vs resize is judged against the
    /// gesture's start frame, never the slot: a window that
    /// can't match its slot's size (min sizes, character
    /// grids — every overflow-cascade window whose app can't
    /// shrink that far) differs from it permanently, and slot
    /// comparison would turn every plain move into a resize.
    /// The window's true frame at drop time. The last AX event of
    /// a fast drag lags the real drop, so read it fresh from the
    /// element; fall back to the reported frame when the element is
    /// gone or reads empty.
    private func liveDropFrame(
        _ id: WindowID,
        fallback: CGRect
    ) -> CGRect {
        guard let element = eventLoop.element(for: id)
        else { return fallback }
        let live = AXHelper.frame(of: element)
        return live == .zero ? fallback : live
    }

    func handleDragEnd(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) {
        dragOverlay.hideAll()
        // A floating window is excluded from the layout swap/resize
        // logic below, but a drop that leaves it under a top app bar
        // hides its title bar and makes it ungrabbable — clamp it
        // back below the strip (#242).
        if state.windows[id]?.isFloating == true {
            let frame = liveDropFrame(id, fallback: frame)
            let clamped = floatFrameClampedBelowTopBar(
                id,
                frame: frame
            )
            if clamped != frame {
                tiler.applyFrame(
                    id,
                    from: frame,
                    to: clamped,
                    animated: false
                )
            }
            return
        }
        guard let space = activeSpace,
            space.mode != .floating,
            space.windows.contains(id),
            state.windows[id]?.isFloating == false
        else { return }

        let frame = liveDropFrame(id, fallback: frame)
        let slots = tiler.calculatedFrames(state: state)
        if slots[id] != nil,
            MouseResize.isResize(from: start, to: frame)
        {
            // Only edges shared with a neighbor trade space;
            // pulling an outer (screen-side) edge snaps back
            // instead of growing windows on the far side.
            // All deltas are measured from the start frame
            // (where the window really was), not the slot.
            let effective =
                MouseResize.keepingInnerEdgeChanges(
                    slot: start,
                    frame: frame,
                    neighbors:
                        slots
                        .filter { $0.key != id }
                        .map(\.value)
                )
            if MouseResize.isResize(
                from: start,
                to: effective
            ) {
                handleResizeEnd(
                    id,
                    slot: start,
                    frame: effective,
                    in: space
                )
            } else {
                retile()
                focusWindow(id, warp: false)
            }
            return
        }
        let target = DragTarget.swapTarget(
            of: id,
            frame: frame,
            slots: slots
        )

        var crossedZones = false
        if let target {
            crossedZones = crossesStackBoundary(
                id,
                target,
                in: space
            )
            state.workspaces.withSpace(space.id) {
                $0.swap(id, target)
            }
        }
        // Applies the swap — honoring `on_window_swap`, like the
        // keyboard swap — or, without a target, snaps/animates the
        // dragged window back into its slot (a relayout).
        retile(
            animated: target != nil
                ? tiler.settings.animations.onWindowSwap : nil
        )
        // The dropped window has the user's attention: make
        // it the focused one, in state and for real. No warp:
        // this focus is mouse-made (#186), and a no-target
        // drop snaps the window back to a slot the pointer
        // may sit outside of.
        focusWindow(id, warp: false)
        if crossedZones {
            scheduleZOrderRestore()
        }
        // A drop that reorders an overflowing track scrambles its
        // pile just like a keyboard track.swap (#193); crossedZones
        // is stack-only, so the two are mutually exclusive.
        scheduleTrackZOrderRestoreIfOverflowing()
    }
}
