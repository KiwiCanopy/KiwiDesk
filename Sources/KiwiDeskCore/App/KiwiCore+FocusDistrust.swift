import Foundation

/// The two sibling-distrust reads `handleWindowFocused` weighs
/// (#465/#496). Split from `KiwiCore+FocusEvents.swift`
/// (350-line ceiling, §2); internal because file-private
/// cannot cross the split.
extension KiwiCore {
    /// Whether a same-app sibling report for `id` is inherently
    /// suspect by WHERE the window lives (#465/#496): a hidden
    /// space always is; a space shown on a display OTHER than
    /// the active space's is too (the cross-display steal — a
    /// forced activation keys the app's MRU window over there).
    /// The active space's own display stays trusted so in-app
    /// window cycling is never fought.
    func distrustsSiblingSpace(
        of id: WindowID
    ) -> Bool {
        guard
            let echoSpace = state.workspaces.space(of: id)
        else { return false }
        guard
            state.workspaces.visibleSpaces.contains(echoSpace)
        else { return true }
        guard
            let active = state.workspaces.activeSpace,
            echoSpace != active
        else { return false }
        let activeDisplay = state.workspaces.display(of: active)
        let echoDisplay = state.workspaces.display(of: echoSpace)
        return echoDisplay != activeDisplay
    }

    /// Whether a same-app sibling of `id` carries a fresh
    /// self-raise stamp NEWER than `id`'s own (#465): the shape
    /// of an activation re-report — raising B activates the
    /// app, which re-reports its old window A. Order, not mere
    /// presence, because stamps are never consumed (#887): after
    /// a fast step A→B both are fresh, and B's own echo must
    /// not be distrusted for A's older raise. An unstamped `id`
    /// ranks below any fresh sibling.
    func siblingRaiseOutranks(
        _ id: WindowID,
        now: Date
    ) -> Bool {
        guard let pid = state.windows[id]?.pid else {
            return false
        }
        let own = selfRaiseStamp(id, now: now) ?? .distantPast
        return selfRaiseStamps.keys.contains { sibling in
            sibling != id
                && state.windows[sibling]?.pid == pid
                && selfRaiseStamp(sibling, now: now)
                    .map { $0 > own } == true
        }
    }

    /// Whether a placement of `id` lies (partly) outside the
    /// visible bounds of the screen its space lays out on (#1161)
    /// — the scrolling void past an edge, where an app that clamps
    /// itself on-screen answers with a focus of its own. Read off
    /// the one `visibleBounds` seam (#531).
    func placementCrossesEdge(
        _ placed: CGRect,
        of id: WindowID
    ) -> Bool {
        guard let space = state.workspaces.space(of: id),
            let screen = TilingEngine.screen(for: space, in: state)
        else { return false }
        return !tiler.visibleBounds(screen).contains(placed)
    }

    /// Whether a left click landed inside `id`'s frame within
    /// the sibling-distrust window — the discriminator that
    /// tells a genuine cross-display click from an activation
    /// re-report (#496). Frames and the stamp are both AX
    /// coordinates.
    func recentClickInside(
        _ id: WindowID,
        now: Date
    ) -> Bool {
        guard let click = lastLeftClick,
            now.timeIntervalSince(click.at)
                < Self.selfRaiseEchoWindow,
            let frame = state.windows[id]?.frame
        else { return false }
        return frame.contains(click.point)
    }
}
