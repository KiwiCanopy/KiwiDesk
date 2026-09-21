import Foundation

/// The menu-bar reveal return (#1532). With the menu bar set to
/// auto-hide, macOS 27 answers the pointer reaching the top edge
/// by activating the last REGULAR app, so there is a bar to
/// reveal — KiwiDesk is an accessory app and owns none — and the
/// clickless focus report that follows has a cmd-tab's shape.
/// Measured 2026-09-21: the activation lands ~190 ms after the
/// pointer reaches the edge, ahead of the bar itself; and
/// re-activating KiwiDesk while the pointer stays there HOLDS —
/// macOS does not steal it back, the previous app's bar stays
/// revealed above the key own window and hides when the pointer
/// leaves. The #958 return one arm over, decided at the report
/// from readable facts rather than armed ahead. The ruling is on
/// the issue and in `docs/design-decisions.md`.
extension KiwiCore {
    /// One return per reveal: a second foreign report inside this
    /// bound is honored, so an activation KiwiDesk cannot hold is
    /// never fought twice. Sized at the echo window.
    static let menuBarRevealReturnWindow: TimeInterval = 1.0

    /// The `handleWindowFocused` arm, between the placement bounce
    /// and the #958 return. Taken only for a report from another
    /// app while the focus anchor is a window of our own pid, no
    /// left press landed inside the echo window (a click into the
    /// revealed bar's menus is the user choosing that app), the
    /// pointer is in the reveal strip, and the re-assert switches
    /// no Desktop (#1345). Re-asserts through the focus COMMAND,
    /// so the report that follows is intended (#1281) and the
    /// scrolling placement distrust does not bounce it (#1414's
    /// class landing on the own window). Returns whether the
    /// report was taken.
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
        focusWindow(intended, warp: false)
        return true
    }

    private func returnedMenuBarRevealRecently(now: Date) -> Bool {
        guard let at = menuBarRevealReturnAt else { return false }
        return now.timeIntervalSince(at)
            < Self.menuBarRevealReturnWindow
    }
}
