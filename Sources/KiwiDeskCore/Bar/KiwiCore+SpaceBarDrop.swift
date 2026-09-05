import AppKit

/// Wiring for the Space Bar drag-drop gesture (#372): connects the
/// drop coordinator to the bars, workspace state, and the
/// spring-switch action. Split from `KiwiCore+Drag.swift` for the
/// file ceiling; the drag handlers themselves stay there.
extension KiwiCore {
    /// Connects the Space Bar drop coordinator to the bars, state,
    /// and the spring-switch action.
    func wireSpaceBarDrop() {
        spaceBarDrop.dwellProvider = { [weak self] in
            self?.tiler.settings.spaceBarStyle.resolvedSpringDelay
                ?? 1.5
        }
        spaceBarDrop.hitTest = { [weak self] point in
            self?.spaceBars.spaceItem(atGlobal: point)
        }
        spaceBarDrop.currentSpace = { [weak self] id in
            self?.state.workspaces.space(of: id)
        }
        spaceBarDrop.setHover = { [weak self] space in
            self?.spaceBars.setDragHover(space)
        }
        spaceBarDrop.beginSweep = {
            [weak self] space, fill, delay in
            self?.spaceBars.beginSpringSweep(
                on: space,
                duration: fill,
                delay: delay
            )
        }
        spaceBarDrop.clearFeedback = { [weak self] in
            self?.spaceBars.clearDragFeedback()
        }
        spaceBarDrop.spring = { [weak self] target, window in
            self?.springSwitchSpace(to: target, dragging: window)
                ?? false
        }
    }

    /// Abnormal drag end (window closed / native tab rekeyed
    /// mid-drag): `DragCoordinator.cancel` never fires `onDragEnd`,
    /// so the gesture teardown that lives there is bypassed. Tear
    /// the Space Bar drop state down here too, scoped to `id`, so a
    /// pending dwell can't fire a phantom spring, `sprungSpace`
    /// can't teleport the next drag, and `dragExemptWindow` can't
    /// leak onto a reused WindowID (#372, review).
    func cancelDrag(_ id: WindowID) {
        drag.cancel(id)
        // A live display crossing (#504) already moved the
        // window's membership; put it back where the gesture
        // started (and always drop the crossing bookkeeping, so
        // a reused WindowID can't inherit a stale gesture).
        revertLiveCrossing(id)
        if tiler.dragExemptWindow == id {
            tiler.dragExemptWindow = nil
        }
        if spaceBarDrop.draggingWindow == id {
            spaceBarDrop.reset()
        }
        // Stop any drag autoscroll (#385) — this gesture is over,
        // and no `handleDragEnd` fires on an abnormal cancel.
        spaceBars.endDragAutoScroll()
    }

    /// Springs the visible space to `target` mid-drag (#372):
    /// eager-moves the dragged window into the target, activates
    /// it, and does a forced, un-animated retile.
    ///
    /// Eager membership (QA fix): moving the window into the target
    /// NOW — not at drop — means the live drag shows the ordinary
    /// drop preview (ghost + drop-zone) in the target's layout, and
    /// the release lands the window in the exact slot under the
    /// cursor. `window` is exempt from `stashInactive` (pinned at
    /// the gesture's first move and re-pinned here), so neither the
    /// membership move nor the retile stashes it mid-drag; an
    /// abnormal end is cleaned up by `cancelDrag`.
    ///
    /// Deliberately NOT `focusSpace` — that warps the cursor to
    /// hand off AX focus, which would rip the pointer out of the OS
    /// drag loop. No focus hand-off, no warp, no settle timer.
    ///
    /// Returns whether it actually sprang, so the drop coordinator
    /// records `sprungSpace` only on a real switch (#445): a refused
    /// sticky move or an already-active target springs nothing.
    @discardableResult
    private func springSwitchSpace(
        to target: SpaceID,
        dragging window: WindowID
    ) -> Bool {
        guard state.workspaces.activeSpace != target else {
            return false
        }
        // The spring is a second membership-mutation path (#372):
        // it re-homes the dragged window directly, not through
        // `moveWindow`, so the #445 sticky guard must fire here too
        // — otherwise dragging a sticky onto a Space Bar item would
        // silently re-home a window that `move_to_space` refuses.
        // Refused → no spring at all (no move, no visible switch);
        // the pill explains why, the drag stays on this space.
        if stickyMoveRefused(window, to: target) { return false }
        tiler.dragExemptWindow = window
        let from = state.workspaces.space(of: window)
        // The one filing (#1150); its float re-anchor stands
        // down on the drag-exempt window, so the pointer keeps
        // owning the placement.
        if from != target {
            fileMembership(window, into: target, from: from)
        }
        state.workspaces.activate(target)
        retile(animated: false, force: true)
        emitSpaceChange()
        return true
    }
}
