import Foundation

/// Layout undo across a window opening or closing (#3601): the
/// event fold rebases the stored steps instead of leaving them to
/// clear at the next undo. A window that closed leaves every step;
/// one placed by `new_window_placement` joins every step of its
/// Space the way it was placed. Any other membership change — a
/// return by rank, a track spawn, a hide, a minimize, a move
/// between Spaces — still clears lazily, as #3515 ruled.
extension KiwiCore {
    /// Every Space's arrangement ahead of a fold that can change
    /// membership, or nil where nothing could be rebased: no
    /// history, or an act open whose step reads the change itself.
    struct LayoutUndoFold {
        let event: KiwiEvent
        let before: [SpaceID: SpaceArrangement]
    }

    func layoutUndoFold(for event: KiwiEvent) -> LayoutUndoFold? {
        switch event {
        case .windowCreated, .windowDestroyed, .appTerminated: break
        default: return nil
        }
        let ledger = layoutHistory
        guard ledger.depth == 0, ledger.pending == nil,
            !ledger.history.isEmpty
        else { return nil }
        return LayoutUndoFold(event: event, before: layoutArrangements())
    }

    /// Rebases the history over what the fold and its handler
    /// changed, read after the handler's last write so a window it
    /// re-filed reads as moved, not opened.
    func rebaseLayoutUndo(
        _ fold: LayoutUndoFold?,
        effects: AppliedEffects,
        gone: WindowGoneReason?
    ) {
        guard let fold, layoutHistory.pending == nil else { return }
        let after = layoutArrangements()
        let was = Self.members(fold.before)
        let now = Self.members(after)
        let closed = Set(was.keys).subtracting(now.keys)
        let opened = Set(now.keys).subtracting(was.keys)
        // A window the handler re-filed beside it (a launch's
        // riders) is a move no step records.
        guard
            was.allSatisfy({
                closed.contains($0.key) || now[$0.key] == $0.value
            })
        else { return }
        // A window gone by a hide or minimize comes back by rank.
        let isClose: Bool
        if case .appTerminated = fold.event {
            isClose = true
        } else {
            isClose = gone == .closed
        }
        let rebase: (SpaceID, SpaceArrangement) -> SpaceArrangement
        if !closed.isEmpty, opened.isEmpty, isClose {
            rebase = { _, side in
                closed.reduce(side) { $0.removing($1) }
            }
        } else if closed.isEmpty, opened.count == 1,
            let spawn = effects.spawnPlaced,
            opened.contains(spawn.window),
            now[spawn.window] == spawn.space,
            let live = after[spawn.space]
        {
            rebase = { space, side in
                space != spawn.space
                    ? side
                    : side.inserting(
                        spawn.window,
                        placement: spawn.placement,
                        anchor: spawn.anchor,
                        from: live
                    )
            }
        } else {
            return
        }
        let changed = Set(
            closed.compactMap { was[$0] } + opened.compactMap { now[$0] }
        )
        var history = layoutHistory.history
        // A Space whose history no longer sits at the pre-fold
        // arrangement already reads as unrecorded; one such Space
        // leaves every Space to its lazy clear, a linked step
        // spanning both.
        guard
            changed.allSatisfy({ space in
                fold.before[space].map { history.sits(space, at: $0) }
                    ?? false
            })
        else { return }
        // What the handler wrote beside the membership — the event
        // retile's heals of weights and session sizes — becomes the
        // stored after, so the next undo still acts.
        history.rebase { space, side in
            if changed.contains(space), side == fold.before[space],
                let live = after[space]
            {
                return live
            }
            return rebase(space, side)
        }
        layoutHistory.history = history
    }

    private static func members(
        _ arrangements: [SpaceID: SpaceArrangement]
    ) -> [WindowID: SpaceID] {
        var out: [WindowID: SpaceID] = [:]
        for (space, arrangement) in arrangements {
            for window in arrangement.windows { out[window] = space }
        }
        return out
    }
}
