import AppKit

/// Wiring for the Space Bar drag-drop gesture (#372): connects the
/// drop coordinator to the bars, workspace state, and the
/// spring-switch action. Split from `KiwiCore+Drag.swift` for the
/// file ceiling; the drag handlers themselves stay there.
extension KiwiCore {
    /// Connects the Space Bar drop coordinator to the bars, state,
    /// and the spring-switch action.
    func wireSpaceBarDrop() {
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

    /// Springs the visible space to `target` mid-drag without
    /// touching the dragged window (#372): activate + a forced,
    /// un-animated retile, with `window` exempt from
    /// `stashInactive` (it is still a member of its source space).
    /// Deliberately NOT `focusSpace` — that warps the cursor to
    /// hand off AX focus, which would rip the pointer out of the
    /// OS drag loop. No focus hand-off, no warp, no settle timer.
    private func springSwitchSpace(
        to target: SpaceID,
        dragging window: WindowID
    ) {
        guard state.workspaces.activeSpace != target else {
            return
        }
        // Belt-and-suspenders: the move handler set this at the
        // gesture's first frame, but pin it again so the retile
        // below can never stash the in-flight window.
        tiler.dragExemptWindow = window
        state.workspaces.activate(target)
        retile(animated: false, force: true)
        emitSpaceChange()
    }
}
