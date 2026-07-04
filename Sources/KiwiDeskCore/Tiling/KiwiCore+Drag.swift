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
    func handleDragEnd(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) {
        dragOverlay.hideAll()
        guard let space = activeSpace,
            space.mode != .floating,
            space.windows.contains(id),
            state.windows[id]?.isFloating == false
        else { return }

        // The last AX event of a fast drag lags the real
        // drop; read the frame fresh instead of trusting it.
        var frame = frame
        if let element = eventLoop.element(for: id) {
            let live = AXHelper.frame(of: element)
            if live != .zero {
                frame = live
            }
        }

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
                focusWindow(id)
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
        // Applies the swap — or, without a target, animates
        // the dragged window back into its slot.
        retile()
        // The dropped window has the user's attention: make
        // it the focused one, in state and for real.
        focusWindow(id)
        if crossedZones {
            scheduleStackZOrderRestore()
        }
    }

    /// Whether a resized event belongs to a mouse gesture:
    /// the button is still down, or it is the trailing AX
    /// event of a fast resize — released moments ago, with
    /// the press having started near the window's slot edge
    /// (where resize drags begin; app-initiated resizes like
    /// a zoom button don't match).
    func isResizeGesture(_ id: WindowID) -> Bool {
        if NSEvent.pressedMouseButtons & 1 == 1 {
            return true
        }
        guard let press = mouse.press,
            let up = press.upAt,
            Date().timeIntervalSince(up) < 1,
            let slot = tiler.calculatedFrames(
                state: state
            )[id]
        else { return false }
        return MouseResize.nearEdge(
            press.location,
            of: slot
        )
    }

    /// Mouse resize of a tiled window, applied on release:
    /// translate the size delta into the same layout change
    /// the `resize` command makes (neighbors give or take
    /// space). Layouts without a parameter for the resized
    /// axis — and snap_back mode — animate the window back.
    private func handleResizeEnd(
        _ id: WindowID,
        slot: CGRect,
        frame: CGRect,
        in space: Space
    ) {
        guard tiler.mouseResize == .layout,
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else {
            retile()
            focusWindow(id)
            return
        }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        let isMaster =
            (tiled.firstIndex(of: id) ?? .max)
            < tiler.settings.stack.masterCount
        let adjustment = MouseResize.translate(
            mode: space.mode,
            isMaster: isMaster,
            slot: slot,
            frame: frame,
            bounds: GeometryUtils.axVisibleFrame(of: screen)
        )
        switch adjustment {
        case .bspRatio(let delta):
            let ratio = tiler.settings.bsp.splitRatio + delta
            tiler.settings.bsp.splitRatio =
                min(max(ratio, 0.1), 0.9)
        case .masterRatio(let delta):
            let ratio =
                tiler.settings.stack.masterRatio + delta
            tiler.settings.stack.masterRatio =
                min(max(ratio, 0.1), 0.9)
        case .scrollWidth(let delta):
            let width =
                tiler.settings.scrolling.windowWidth + delta
            tiler.settings.scrolling.windowWidth =
                max(width, 100)
        case nil:
            break
        }
        retile()
        focusWindow(id)
    }
}
