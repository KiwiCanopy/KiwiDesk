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

    /// The apply's own pass, landing where an owed follow goes. The
    /// landing Space is made active ahead of the pass, so the pass
    /// draws it once rather than parking the window the restore
    /// moved (the launch follow's #1599 rule), and `followSwitch`
    /// then pays the switch whole — focus, warp, settle, the #412
    /// raise and its own exempt pass, which also lays out a pass
    /// the #804 gate held. Re-judged first, since the apply's held
    /// returns ran since the restore.
    func retileFollowing(_ follow: RestoreFollow?, pass: RetilePass) {
        guard let owed = follow, stillOwed(owed) else {
            retile(pass: pass)
            emitSpaceChange()
            return
        }
        onLog(
            "restore follow: w\(owed.window.raw) into space "
                + "\(owed.space.raw), the one it left empty"
        )
        let leaving = (focusedScreen, frontmostPIDProvider?())
        state.workspaces.activate(owed.space)
        retile(pass: pass)
        followSwitch(
            to: owed.space,
            focusing: owed.window,
            leaving: leaving
        )
    }

    private func stillOwed(_ follow: RestoreFollow) -> Bool {
        state.workspaces.activeSpace == follow.left
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
