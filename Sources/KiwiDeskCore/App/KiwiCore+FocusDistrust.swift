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
        let own = selfRaiseStamps[id] ?? .distantPast
        return selfRaiseStamps.contains {
            $0.key != id
                && state.windows[$0.key]?.pid == pid
                && $0.value > own
                && now.timeIntervalSince($0.value)
                    < Self.selfRaiseEchoWindow
        }
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
