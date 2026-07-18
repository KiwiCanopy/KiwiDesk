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
        spaceBarDrop.beginSweep = { [weak self] space, duration in
            self?.spaceBars.beginSpringSweep(
                on: space,
                duration: duration
            )
        }
        spaceBarDrop.clearFeedback = { [weak self] in
            self?.spaceBars.clearDragFeedback()
        }
        spaceBarDrop.spring = { [weak self] target, window in
            self?.springSwitchSpace(to: target, dragging: window)
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
        if tiler.dragExemptWindow == id {
            tiler.dragExemptWindow = nil
        }
        if spaceBarDrop.draggingWindow == id {
            spaceBarDrop.reset()
        }
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
    private func springSwitchSpace(
        to target: SpaceID,
        dragging window: WindowID
    ) {
        guard state.workspaces.activeSpace != target else {
            return
        }
        tiler.dragExemptWindow = window
        let from = state.workspaces.space(of: window)
        if from != target {
            addFocusedToSpace(window, to: target)
            state.workspaces.focus(window, in: target)
            emitWindowMovedToSpace(
                window,
                app: state.windows[window]?.appName ?? "",
                bundleID: state.windows[window]?.appBundleID,
                from: from,
                to: target
            )
        }
        state.workspaces.activate(target)
        retile(animated: false, force: true)
        emitSpaceChange()
    }
}
