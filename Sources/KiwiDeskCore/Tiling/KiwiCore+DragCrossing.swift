import AppKit
import Foundation

/// Live cross-display "make-room" (#504): dragging a tiled window
/// onto another display moves its MEMBERSHIP there mid-drag, after
/// a short dwell — the destination's windows slide apart to open a
/// real slot under the cursor while the dragged window stays
/// pinned under the pointer (`dragExemptWindow`, never re-framed
/// mid-drag). From then on the drag is an ordinary SAME-display
/// gesture in the destination space — the Space-Bar-spring model
/// (#372) keyed on displays — so the drop swaps / snaps exactly
/// like a local drag, and `relocateAcrossDisplay` (#492) remains
/// only the fast-flick path whose dwell never fired.
extension KiwiCore {
    /// Wires the crossing coordinator (once, from `wireDrag`).
    func wireDragCrossing() {
        dragCrossing.displayAt = { point in
            NSScreen.screens
                .first { $0.frame.contains(point) }?
                .kiwiDisplay?.id
        }
        dragCrossing.onCross = { [weak self] id, display in
            self?.performLiveCrossing(id, onto: display)
        }
    }

    /// Feeds the crossing debounce from the live drag. Sticky
    /// windows are excluded: their cross-display drop keeps the
    /// full #445 gate + pill semantics of the drop-commit path,
    /// and live-moving a sticky would fight the sticky render
    /// pipeline mid-gesture.
    func updateDragCrossing(_ id: WindowID, cursor: CGPoint) {
        guard state.windows[id]?.isSticky != true else {
            dragCrossing.cancelPending(for: id)
            return
        }
        let home = state.workspaces.space(of: id)
            .flatMap { state.workspaces.display(of: $0) }
        dragCrossing.moved(id, cursor: cursor, homeDisplay: home)
    }

    /// The debounced crossing: eager-moves the dragged window into
    /// the active space of the display the cursor settled on.
    /// Mirrors `relocateAcrossDisplay`'s placement (shared
    /// `insertDropped` choke point) but, like the Space-Bar spring,
    /// asserts NO AX focus and schedules NO settle — the pointer is
    /// inside the OS drag loop; the drop path owns focus.
    private func performLiveCrossing(
        _ id: WindowID,
        onto display: DisplayID
    ) {
        guard
            // Released during the dwell: the drop-commit
            // relocate owns the gesture now.
            drag.isMousePressed(),
            // The dwell disarms only on AX move events, and
            // Electron/WebKit apps deliver those 100–300 ms
            // late — longer than the dwell (§5). Re-validate
            // the LIVE cursor at fire time: still on the display
            // the dwell armed for, and not aiming at a Space Bar
            // item (a competing membership mover).
            !spaceBarDrop.isArmed,
            dragCrossing.displayAt(drag.cursorLocation())
                == display,
            let originID = state.workspaces.space(of: id),
            let origin = state.workspaces[originID],
            origin.windows.contains(id),
            origin.mode != .floating,
            state.windows[id]?.isFloating == false,
            let destID = state.workspaces.activeSpace(on: display),
            destID != originID,
            let dest = state.workspaces[destID],
            // A floating-mode destination has no layout to make
            // room in; the drop-commit relocate handles it.
            dest.mode != .floating
        else { return }
        // The #445 sticky gate, once per gesture: the refusal
        // pill should not re-flash on every dwell while the
        // cursor stays on the refused display.
        guard !dragCrossing.stickyRefused(id) else { return }
        if stickyMoveRefused(id, to: destID) {
            dragCrossing.markStickyRefused(id)
            return
        }
        dragCrossing.recordOriginIfNeeded(
            id,
            space: originID,
            index: origin.windows.firstIndex(of: id) ?? 0
        )
        // Re-pin against stashInactive across the membership
        // move, exactly like the spring (#372).
        tiler.dragExemptWindow = id
        // Cursor slot resolved BEFORE membership changes, from
        // the same cursor rule as preview and drop (#492).
        let slots = tiler.calculatedFrames(state: state)
        let target = DragTarget.swapTarget(
            of: id,
            at: GeometryUtils.axPoint(drag.cursorLocation()),
            slots: slots
        )
        insertDropped(id, onto: target, into: destID)
        state.workspaces.focus(id, in: destID)
        // Focused display follows the drag there (#446), so the
        // preview machinery reads the destination as "this
        // space" from now on.
        state.workspaces.activate(destID)
        emitWindowMovedToSpace(
            id,
            app: state.windows[id]?.appName ?? "",
            bundleID: state.windows[id]?.appBundleID,
            from: originID,
            to: destID
        )
        dragCrossing.markCrossed(id)
        // Both displays reflow; the slide IS the feature, so
        // animate with the swap animation. The dragged window is
        // exempt and never re-framed. Forced, like the spring: a
        // membership mutation must apply exactly, not be
        // swallowed by the ±2 pt echo tolerance.
        retile(
            animated: tiler.settings.animations.onWindowSwap,
            force: true
        )
        // Inserting into an overflowing stack / track / scrolling
        // pile scrambles its stacking — the same §5 obligation
        // the drop-commit relocate honors.
        scheduleZOrderRestore()
        emitSpaceChange()
    }

    /// Abnormal drag end (window closed / rekeyed mid-drag) after
    /// a live crossing: puts the membership back where the gesture
    /// started, at its old index. A drop back on the origin
    /// display needs none of this — crossing back is symmetric —
    /// and a window that died mid-drag left state already.
    func revertLiveCrossing(_ id: WindowID) {
        defer { dragCrossing.endGesture(id) }
        guard
            let origin = dragCrossing.origin(for: id),
            state.windows[id] != nil,
            let current = state.workspaces.space(of: id),
            current != origin.space,
            state.workspaces[origin.space] != nil
        else { return }
        state.workspaces.add(id, to: origin.space)
        state.workspaces.withSpace(origin.space) {
            let last = $0.windows.count - 1
            $0.move(id, to: min(origin.index, max(last, 0)))
        }
        // `add` re-homing cleared `lastFocused` (it was this
        // window, stamped at the crossing); re-stamp it in the
        // restored home so bar accents / focus-yield paths don't
        // read a startup-like nil (review).
        state.workspaces.focus(id, in: origin.space)
        state.workspaces.activate(origin.space)
        emitWindowMovedToSpace(
            id,
            app: state.windows[id]?.appName ?? "",
            bundleID: state.windows[id]?.appBundleID,
            from: current,
            to: origin.space
        )
        retile(animated: false, force: true)
        // The revert re-inserts into a possibly-overflowing
        // stack / track / pile — the same §5 obligation the
        // crossing itself honors (review).
        scheduleZOrderRestore()
        emitSpaceChange()
    }
}
