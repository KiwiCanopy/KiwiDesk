import Foundation

/// A profile switch's restore that takes the focused window out of
/// the active Space and leaves it empty is followed (#3191 ▸
/// Ruling): the user lands where the window went, as a
/// move-and-follow would, never in the empty Space it left.
extension KiwiCore {
    /// What a restore owes: the Space the focused window went to,
    /// and the window.
    struct RestoreFollow: Equatable {
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
            landed != active,
            let left = state.workspaces[active],
            state.effectiveMembers(of: left).isEmpty
        else { return nil }
        return RestoreFollow(space: landed, window: focused)
    }

    /// Pays a restore's follow once the apply has laid out the
    /// arrangement — a whole switch, so the landing Space's float
    /// layer lifts too (#412).
    func payRestoreFollow(_ follow: RestoreFollow?) {
        guard let follow,
            state.workspaces.space(of: follow.window) == follow.space
        else { return }
        onLog(
            "restore follow: w\(follow.window.raw) into space "
                + "\(follow.space.raw), the one it left empty"
        )
        followSwitch(to: follow.space, focusing: follow.window)
    }
}
