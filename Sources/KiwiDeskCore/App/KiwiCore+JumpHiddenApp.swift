import Foundation

/// Move here on a hidden app (#1513, #1875): the unhide brings its
/// windows back into their own Spaces, and the one it reports
/// focused is filed into the Space the Move here was asked in,
/// ahead of the focus-follow that would switch the user away to it.
extension KiwiCore {
    /// Unhides `pid` and owes its returning focused window the move
    /// into `active` — only a window whose title contains `text`,
    /// where `move_here` named one.
    func moveHiddenApp(
        _ pid: pid_t,
        into active: SpaceID,
        matching text: String?
    ) {
        jump.oweApp(pid, in: active, at: wallClock(), matching: text)
        jump(to: .hiddenApp(pid))
    }

    /// Pays at the app's first honored focus report, in
    /// `handleWindowFocused`, ahead of the #1207 memory, which
    /// then files the window under the Space it now holds. Stands
    /// down past the follow's bound, off the Space it was owed for,
    /// after a press or a commanded focus since, and for a window
    /// no move can take — full screen, or held by the sticky gate.
    /// Returns whether it filed the window; the handler, which
    /// decides whether this report retiles, places it.
    @discardableResult
    func payHiddenAppMove(focused window: WindowID) -> Bool {
        guard let managed = state.windows[window],
            let owed = jump.takeApp(managed.pid)
        else { return false }
        let age = wallClock().timeIntervalSince(owed.at)
        let pressed = launchFollow.pressAge?().map { $0 < age } ?? false
        let commanded =
            eventLoop.lastCommandedFocus.map { $0 > owed.commandedAt }
            ?? false
        let landed = state.workspaces.space(of: window)
        guard age < FollowFocusIntent.drainWindow,
            state.workspaces.activeSpace == owed.space,
            !pressed, !commanded, !managed.isFullscreen,
            landed != owed.space,
            stickyMoveBlock(window, to: owed.space) == nil
        else {
            onLog("move here: w\(window.raw) unhidden — move stood down")
            return false
        }
        // Logged, never drawn: the follow is about to switch away
        // from the Space the pill would draw on.
        if let text = owed.matching,
            !Self.titleMatches(managed.title, text)
        {
            onLog("move here: w\(window.raw) unhidden — no title match")
            return false
        }
        fileMembership(window, into: owed.space, from: landed)
        onLog("move here: unhidden w\(window.raw) filed here")
        return true
    }
}
