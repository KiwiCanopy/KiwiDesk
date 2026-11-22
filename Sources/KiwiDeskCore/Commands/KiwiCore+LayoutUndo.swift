import Foundation

/// `undo_layout` and `redo_layout` (#3515): take the active
/// Space's last step back, or again. A step acts only while every
/// Space it names still equals the state it left; otherwise the
/// change in between went unrecorded, so those Spaces' history is
/// cleared and the press refuses.
extension KiwiCore {
    static let undoLayoutCommand = "undo_layout"
    static let redoLayoutCommand = "redo_layout"

    /// Commands that never record a step of their own.
    static let layoutStepCommands: Set<String> = [
        undoLayoutCommand, redoLayoutCommand,
    ]

    func takeLayoutStep(_ stack: LayoutUndoStacks.Stack) -> CommandResponse {
        guard let active = state.workspaces.activeSpace else {
            return .fail("no active space")
        }
        // An enclosing bracket must not record this as a new step.
        layoutHistory.tookStep = true
        let word = stack == .undo ? "undo" : "redo"
        switch layoutHistory.history.candidate(stack, of: active) {
        case .empty:
            return refuseLayoutStep("nothing to \(word) on this Space")
        case .blocked:
            layoutHistory.history.clear(active)
            return refuseLayoutStep(
                "a move between Spaces changed since; history cleared"
            )
        case .ready(let step):
            let from = stack == .undo ? step.after : step.before
            let to = stack == .undo ? step.before : step.after
            let now = layoutArrangements()
            guard from.allSatisfy({ now[$0.key] == $0.value }) else {
                step.spaces.forEach { layoutHistory.history.clear($0) }
                return refuseLayoutStep(
                    "this Space changed since its last step; "
                        + "history cleared"
                )
            }
            layoutHistory.history.take(step, from: stack)
            restoreArrangements(to, from: from)
            return .ok()
        }
    }

    /// The refusal sound for a pressed undo, as an unbound key's.
    private func refuseLayoutStep(_ reason: String) -> CommandResponse {
        if keys.isFiring { soundPanelRefusal() }
        return .fail(reason)
    }

    /// Writes `target` back over `current`: a window that moved
    /// between Spaces goes back through the move verb first, then
    /// each Space takes its mode, order and sizes.
    private func restoreArrangements(
        _ target: [SpaceID: SpaceArrangement],
        from current: [SpaceID: SpaceArrangement]
    ) {
        for (space, arrangement) in target {
            for window in arrangement.windows
            where state.workspaces.space(of: window) != space {
                moveWindow(window, to: space, follow: false)
            }
        }
        for (space, arrangement) in target {
            if current[space]?.mode != arrangement.mode {
                setSpaceMode(space, arrangement.mode, keepingSizes: true)
            }
            state.workspaces.withSpace(space) { $0.restore(arrangement) }
            restoreSessionRatios(arrangement.sizing.ratios, of: space)
            if let restored = state.workspaces[space],
                current[space]?.mode != arrangement.mode
            {
                emitLayoutChange(space: restored)
            }
        }
        retile(animated: true, pass: .apply)
        if activeTrackOverflows {
            requestZOrderRestoreAfterDispatch()
        }
    }
}
