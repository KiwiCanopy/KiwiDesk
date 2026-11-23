import Foundation

/// `undo_layout` and `redo_layout` (#3515): take the active
/// Space's last step back, or again. A step acts only while every
/// Space it names still equals the state it left and the move verb
/// takes every window back; otherwise those Spaces' history is
/// cleared and the press refuses.
extension KiwiCore {
    static let undoLayoutCommand = "undo_layout"
    static let redoLayoutCommand = "redo_layout"

    /// Commands that never record a step of their own.
    static let layoutStepCommands: Set<String> = [
        undoLayoutCommand, redoLayoutCommand,
    ]

    func takeLayoutStep(
        _ stack: LayoutUndoStacks.Stack
    ) -> CommandResponse {
        guard let active = state.workspaces.activeSpace else {
            return .fail("no active space")
        }
        // An enclosing bracket must not record this as a new step.
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
            // An open step this undo runs inside records nothing.
            noteLayoutStepTaken()
            // The move verb decides; a window it refused leaves its
            // Space's members wrong, so the moves that landed go back
            // and nothing else is written.
            let moved = moveBack(to)
            guard membersMatch(to) else {
                for (window, origin) in moved {
                    moveWindow(window, to: origin, follow: false)
                }
                step.spaces.forEach { layoutHistory.history.clear($0) }
                retile(animated: true)
                return refuseLayoutStep(
                    "a window this step moves back cannot change "
                        + "Space now; history cleared"
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

    /// Files each window `target` names back into its Space
    /// through the move verb, which owns every refusal, and answers
    /// the windows that moved with the Space each left.
    private func moveBack(
        _ target: [SpaceID: SpaceArrangement]
    ) -> [(WindowID, SpaceID)] {
        var moved: [(WindowID, SpaceID)] = []
        for (space, arrangement) in target {
            for window in arrangement.windows {
                guard let origin = state.workspaces.space(of: window),
                    origin != space
                else { continue }
                moveWindow(window, to: space, follow: false)
                if state.workspaces.space(of: window) == space {
                    moved.append((window, origin))
                }
            }
        }
        return moved
    }

    /// Whether every Space `target` names holds its members now.
    private func membersMatch(
        _ target: [SpaceID: SpaceArrangement]
    ) -> Bool {
        target.allSatisfy { space, arrangement in
            state.workspaces[space].map {
                Set($0.windows) == Set(arrangement.windows)
            } ?? false
        }
    }

    /// Writes `target` back over `current`, its members already
    /// home: each Space takes its mode, order and sizes, in one pass
    /// that names any Maximize the reorder ended.
    private func restoreArrangements(
        _ target: [SpaceID: SpaceArrangement],
        from current: [SpaceID: SpaceArrangement]
    ) {
        var ended: Set<WindowID> = []
        for (space, arrangement) in target {
            // `membersMatch` held for every Space before this runs.
            guard let live = state.workspaces[space] else { continue }
            if let filled = state.handMaximizedWindow(of: live) {
                ended.insert(filled)
            }
            let modeChanged = current[space]?.mode != arrangement.mode
            if modeChanged {
                setSpaceMode(space, arrangement.mode, keepingSizes: true)
            }
            state.workspaces.withSpace(space) { $0.restore(arrangement) }
            restoreSessionRatios(arrangement.sessionSizes.ratios, of: space)
            if modeChanged, let restored = state.workspaces[space] {
                emitLayoutChange(space: restored)
            }
        }
        // A Maximize the reorder ended is named on the pass (#2676);
        // slots move, so nothing is promised spring-sized (#593).
        retile(animated: true, pass: .apply, stateChange: ended)
        // A reorder can change which windows overlap (#153).
        if !scheduleScrollingZOrderRestoreIfOverflowing() {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
    }
}
