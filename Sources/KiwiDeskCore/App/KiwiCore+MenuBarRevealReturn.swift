import Foundation

/// The menu-bar reveal return (#1532): with the bar set to
/// auto-hide, macOS 27 answers the pointer reaching the top edge
/// by activating the last REGULAR app so it has a bar to reveal —
/// KiwiDesk is an accessory app and owns none — and the clickless
/// focus report that follows has a cmd-tab's shape. The #958
/// return one arm over, decided at the report; the measurement
/// and the ruling are in `docs/design-decisions.md`.
extension KiwiCore {
    /// One return per reveal: a second foreign report inside this
    /// bound is honored, so an activation KiwiDesk cannot hold is
    /// never fought twice. The echo window, derived, so the two
    /// cannot drift.
    static let menuBarRevealReturnWindow = zOrderRaiseEchoWindow

    /// The `handleWindowFocused` arm, between the placement bounce
    /// and the #958 return — its guard list is the roster of what
    /// the arm reads: a report from another app while `intended`
    /// (the active Space's focused window before the report, so a
    /// sticky own window rendering as a traveler is not one) is a
    /// window of our own pid, no left press inside the echo window
    /// (a click into the revealed bar's menus is the user choosing
    /// that app), the one-shot bound open, the pointer in the
    /// reveal strip, and a re-assert that switches no Desktop
    /// (#1345). Re-asserts with the STAMPED raise: `raiseWindow`
    /// mints the self stamp, so the report that follows is our
    /// own echo (#1281's point) — never the focus command, whose
    /// displacement note would arm the scrolling placement bounce
    /// against every later report from that app for the ledger's
    /// window. Returns whether the report was taken.
    func returnMenuBarReveal(
        id: WindowID,
        intended: WindowID?,
        now: Date
    ) -> Bool {
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        guard let intended, intended != id,
            state.windows[intended]?.pid == own,
            let reported = state.windows[id], reported.pid != own,
            !recentLeftPress(now: now),
            !returnedMenuBarRevealRecently(now: now),
            mouse.pointerInMenuBarStrip(),
            !reassertCrossesDesktops(intended, against: id)
        else { return false }
        menuBarRevealReturnAt = now
        onLog(
            "focus: w\(id.raw) menu-bar reveal activation returned; "
                + "re-focusing w\(intended.raw) (#1532)"
        )
        if let space = state.workspaces.space(of: intended) {
            state.workspaces.focus(intended, in: space)
        }
        raiseWindow(intended)
        updateBorders()
        updateStickyMarks()
        return true
    }

    private func returnedMenuBarRevealRecently(now: Date) -> Bool {
        guard let at = menuBarRevealReturnAt else { return false }
        return now.timeIntervalSince(at)
            < Self.menuBarRevealReturnWindow
    }
}
