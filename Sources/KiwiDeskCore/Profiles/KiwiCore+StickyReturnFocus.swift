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
    /// Desktop was left with; the last return's debt goes first.
    /// macOS's own restore report, which beats the handler, has
    /// already overwritten the memory — the departure's filing is
    /// what survives it.
    func oweStickyReturn(native: SkyLight.SpaceID?) {
        desktopMemory.stickyReturn = nil
        guard let native,
            let id = desktopMemory.stickyLeft.removeValue(forKey: native),
            state.windows[id] != nil
        else { return }
        desktopMemory.stickyReturn = id
        onLog(
            "desktop return: w\(id.raw) left with the focus — owed "
                + "at the settle (#1564)"
        )
    }

    /// Pays the debt at the settle, once the carry has landed:
    /// the window must still be carried and render on the active
    /// Space, and no click may have chosen since the switch.
    /// Returns whether it raised.
    func payStickyReturn() -> Bool {
        guard let id = desktopMemory.stickyReturn else { return false }
        desktopMemory.stickyReturn = nil
        if let click = lastLeftClick, click.at >= lastDesktopSwitch {
            onLog(
                "desktop return: w\(id.raw) not raised — a click "
                    + "since the switch chose (#1564)"
            )
            return false
        }
        guard let window = state.windows[id],
            stickyReachCarried().contains(id),
            state.stickyRenderSpace(of: window)
                == state.workspaces.activeSpace
        else { return false }
        guard state.workspaces.lastFocused != id else { return true }
        onLog("desktop return: focus back to carried w\(id.raw) (#1564)")
        focusWindow(id, refocusRetile: false, warp: true)
        return true
    }
}
