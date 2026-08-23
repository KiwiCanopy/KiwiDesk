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
                < Self.selfRaiseSiblingWindow,
            let frame = state.windows[id]?.frame
        else { return false }
        return frame.contains(click.point)
    }
}
