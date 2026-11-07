import ApplicationServices

/// Jump's arm for a window on its own native full-screen Space
/// (#2939), which no Space or Desktop switch reaches (#670). Jump
/// is a verb that means to switch, so this raise passes the #1345
/// gate on purpose; `JumpFullScreenSeamTests` holds it to Jump.
extension KiwiCore {
    /// Raises `id` on its full-screen Space, else brings its app
    /// forward — the residue for a window KiwiDesk holds no live
    /// element for (full screen since before KiwiDesk adopted it).
    func jumpToFullScreen(_ id: WindowID, pid: pid_t) {
        let tracked = state.windows[id] != nil
        let element =
            tracked
            ? eventLoop.element(for: id)
            : eventLoop.awayElements.element(
                of: id,
                away: Set(state.awayWindows.keys)
            )
        if let element, openOrFocus.raiseFullScreen(element, id, pid) {
            // Our own raise, so its report is no bounce (#1161, #465).
            if tracked { stampSelfRaise(id, now: wallClock()) }
            onLog("jump: w\(id.raw) is full screen — raised on its Space")
            return
        }
        onLog("jump: w\(id.raw) is full screen — app activated")
        openOrFocus.activate(pid)
    }
}
