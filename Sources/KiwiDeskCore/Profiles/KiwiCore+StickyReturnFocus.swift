import Foundation

/// A carried sticky window's focus on a Desktop return (#1564).
/// Reach is a carry that lands after macOS restored the arriving
/// Desktop's own focus, so the focus a Desktop was LEFT with,
/// when it was a carried sticky window, is filed at the
/// departure, owed at the return and paid at the settle — unless
/// a click since the switch chose another window.
extension KiwiCore {
    /// The departure half of the switch handler: the Space the
    /// Desktop being left was showing (#888), and the carried
    /// sticky window its last honored focus was, if any. Read
    /// while `lastDesktopSpace` still names the Desktop left.
    func rememberDeparture(of active: SpaceID, leaving: DesktopKey) {
        rememberVirtualSpace(active, leaving: leaving)
        guard let native = desktopMemory.lastDesktopSpace else { return }
        let carried = stickyReachCarried()
        desktopMemory.stickyLeft[native] =
            desktopMemory
            .lastHonoredOn[native]
            .flatMap { carried.contains($0) ? $0 : nil }
    }

    /// Owes the carried sticky window the arriving `native`
    /// Desktop was left with — `oweReturningFocus` cleared the
    /// last debt and ruled the follow's precedence first. macOS's
    /// own restore report, which beats the handler, has already
    /// overwritten the memory; the departure's filing survives it.
    func oweStickyReturn(native: SkyLight.SpaceID) {
        guard let id = desktopMemory.stickyLeft.removeValue(forKey: native),
            state.windows[id] != nil
        else { return }
        desktopMemory.stickyReturn = id
        onLog(
            "desktop return: w\(id.raw) left with the focus — owed "
                + "at the settle (#1564)"
        )
    }

    /// Takes the debt at the head of the settle, so a settle that
    /// stands down, or pays the #1207 debt instead, still ends it.
    func takeStickyReturn() -> WindowID? {
        defer { desktopMemory.stickyReturn = nil }
        return desktopMemory.stickyReturn
    }

    /// Pays `owed` once the carry has landed: still carried, on
    /// the active Space, raisable without a Desktop switch, and no
    /// click since the switch. A focus honored meanwhile already
    /// retired it (`rememberHonoredFocus`). True when it took the
    /// focus, which stands the settle's own refocus down.
    func payStickyReturn(_ owed: WindowID?) -> Bool {
        guard let id = owed else { return false }
        if leftPress(since: lastDesktopSwitch) {
            onLog(
                "desktop return: w\(id.raw) not raised — a click "
                    + "since the switch chose (#1564)"
            )
            return false
        }
        guard let window = state.windows[id],
            stickyReachCarried().contains(id),
            state.stickyRenderSpace(of: window)
                == state.workspaces.activeSpace,
            !raiseCrossesDesktops(id)
        else { return false }
        guard state.workspaces.lastFocused != id else { return true }
        onLog("desktop return: focus back to carried w\(id.raw) (#1564)")
        focusWindow(id, refocusRetile: false, warp: true)
        return true
    }
}
