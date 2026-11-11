import Foundation

/// A profile switch's restore that takes the focused window out of
/// the active Space and leaves it empty is followed (#3191 ▸
/// Ruling): the user lands where the window went, as a
/// move-and-follow would, never in the empty Space it left.
extension KiwiCore {
    /// What a restore owes: the Space it left empty, the Space the
    /// focused window went to, and the window.
    struct RestoreFollow: Equatable {
        let left: SpaceID
        let space: SpaceID
        let window: WindowID
    }

    /// The follow a restore owes, judged after its moves:
    /// `focused` is the active Space's focus before them, `active`
    /// that Space. Nil where the window stayed, other windows are
    /// still shown there, or the window went nowhere live.
    func restoreFollow(
        focused: WindowID?,
        leaving active: SpaceID?
    ) -> RestoreFollow? {
        guard let focused, let active,
            let landed = state.workspaces.space(of: focused),
            landed != active, leftEmpty(active)
        else { return nil }
        return RestoreFollow(left: active, space: landed, window: focused)
    }

    /// The apply's own pass, landing where an owed follow goes: the
    /// landing Space is made active ahead of the pass, so the pass
    /// draws it once rather than parking the window the restore
    /// moved for a switch to bring back (the launch follow's
    /// #1599 rule), then the focus and the landing float raise
    /// (#412) are paid. Re-judged first, since the apply's held
    /// returns ran since the restore. A bound Desktop switch's
    /// apply follows nothing: its handler activates the arriving
    /// Space itself (the scope `defersRuleSweepToSwitchPass` marks).
    func retileFollowing(_ follow: RestoreFollow?, pass: RetilePass) {
        let owed = follow.flatMap { stillOwed($0) ? $0 : nil }
        let priorFrontmost = frontmostPIDProvider?()
        let priorScreen = focusedScreen
        if let owed {
            onLog(
                "restore follow: w\(owed.window.raw) into space "
                    + "\(owed.space.raw), the one it left empty"
            )
            state.workspaces.activate(owed.space)
        }
        retile(pass: pass)
        emitSpaceChange()
        guard let owed else { return }
        if focusWindow(owed.window, refocusRetile: false, warp: false) {
            warpForSwitch(
                to: owed.space,
                focusing: owed.window,
                leaving: priorScreen
            )
        }
        scheduleSpaceSettle(owed.space, priorFrontmost: priorFrontmost)
        raiseLandingFloats(thenFocus: owed.window)
    }

    private func stillOwed(_ follow: RestoreFollow) -> Bool {
        !defersRuleSweepToSwitchPass
            && state.workspaces.activeSpace == follow.left
            && leftEmpty(follow.left)
            && state.workspaces.space(of: follow.window) == follow.space
    }

    /// Whether `space` shows no window now.
    private func leftEmpty(_ space: SpaceID) -> Bool {
        state.workspaces[space].map {
            state.effectiveMembers(of: $0).isEmpty
        } ?? false
    }
}
