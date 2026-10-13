import Foundation

/// The reveal return's state (#1532, #2224): the owed return, and
/// whether KiwiDesk's own status menu is open, which the GUI sets
/// through `statusMenuDidOpen` / `statusMenuDidClose`.
struct MenuBarRevealState {
    var debt: MenuBarRevealDebt?
    var statusMenuOpen = false
}

/// A menu-bar reveal's owed return (#1532, #2224): the own window
/// the reveal's activation took the focus from, and when.
struct MenuBarRevealDebt {
    /// The own window to give the focus back to.
    let window: WindowID
    /// The foreign window whose report the reveal produced; a
    /// repeat of it is the same reveal.
    let revealed: WindowID
    /// Its app, whose open menu keeps the revealed bar up.
    let revealedPID: pid_t
    /// The report's wall time, which the bound runs from.
    let armedAt: Date
    /// The report's monotonic time — a commanded focus since does.
    let commandedAt: ContinuousClock.Instant
}

/// The menu-bar reveal return (#1532): with the bar set to
/// auto-hide, macOS 27 answers the pointer reaching the top edge
/// by activating the last REGULAR app so it has a bar to reveal —
/// KiwiDesk is an accessory app and owns none — and the clickless
/// focus report that follows has a cmd-tab's shape. Since #2224
/// the return is OWED while the bar shows and paid once it hides:
/// returned at once, macOS took the activation back every ~1.3 s
/// for as long as the pointer stayed (macOS 27.0.1). The ruling
/// and the measurement are in `docs/design-decisions.md`.
extension KiwiCore {
    /// How often an owed return looks for the bar to hide.
    static let menuBarRevealPoll: Duration = .milliseconds(150)
    /// How long a return may stay owed before it is dropped.
    static let menuBarRevealBound: TimeInterval = 30

    /// The `handleWindowFocused` arm, between the placement bounce
    /// and the #958 return — its guard list is the roster of what
    /// the arm reads: a report from another app while `intended`
    /// (the active Space's focused window before the report, so a
    /// sticky own window rendering as a traveler is not one) is a
    /// window of our own pid, no recent click that reached the
    /// reported window (a click into the revealed bar's menus
    /// reaches none and chooses nothing), the pointer in the
    /// reveal strip or our own status
    /// menu open — on any macOS, since no foreign activation while
    /// our menu tracks is the user's — and a re-assert that
    /// switches no Desktop (#1345).
    /// Takes the report WITHOUT honoring it and owes the return;
    /// a repeat of the same report is the same reveal, while a
    /// report for any other foreign window is the user switching,
    /// which drops the debt and is honored. Returns whether the
    /// report was taken.
    func returnMenuBarReveal(
        id: WindowID,
        intended: WindowID?,
        now: Date
    ) -> Bool {
        if let debt = menuBarReveal.debt {
            guard id == debt.revealed else {
                dropMenuBarRevealDebt("another window reported")
                return false
            }
            keepStateFocus(on: debt.window)
            return true
        }
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        guard let intended, intended != id,
            state.windows[intended]?.pid == own,
            let reported = state.windows[id], reported.pid != own,
            !recentClickReached(id, now: now),
            menuBarReveal.statusMenuOpen
                || mouse.pointerInMenuBarStrip(),
            !reassertCrossesDesktops(intended, against: id)
        else { return false }
        menuBarReveal.debt = MenuBarRevealDebt(
            window: intended,
            revealed: id,
            revealedPID: reported.pid,
            armedAt: now,
            commandedAt: .now
        )
        onLog(
            "focus: w\(id.raw) menu-bar reveal activation; "
                + "w\(intended.raw) owed its return (#1532)"
        )
        keepStateFocus(on: intended)
        scheduleMenuBarRevealPayment()
        return true
    }

    /// The report already moved state focus: put it back on the own
    /// window, raising nothing while the bar shows.
    private func keepStateFocus(on window: WindowID) {
        if let space = state.workspaces.space(of: window) {
            state.workspaces.focus(window, in: space)
        }
        updateBorders()
        updateStickyMarks()
    }

    /// The GUI's status menu opened: while it is open an owed
    /// return waits, as it does for the bar (#2224).
    public func statusMenuDidOpen() {
        menuBarReveal.statusMenuOpen = true
    }

    /// The status menu closed: an owed return is paid at the next
    /// poll — AppKit closes the menu BEFORE the picked row runs, so
    /// a row that moves the focus stands it down first — unless
    /// the bar still shows.
    public func statusMenuDidClose() {
        menuBarReveal.statusMenuOpen = false
        guard menuBarReveal.debt != nil else { return }
        scheduleMenuBarRevealPayment()
    }

    private func scheduleMenuBarRevealPayment() {
        deferred.schedule(
            .menuBarRevealReturn,
            after: Self.menuBarRevealPoll
        ) { [weak self] in
            self?.payMenuBarRevealIfDue()
        }
    }

    /// Pays an owed return once the bar has hidden — the pointer
    /// out of the strip, no menu of the revealed app open, and the
    /// status menu closed — with the
    /// STAMPED raise, so the report that follows is our own echo
    /// (#1281) and the scrolling placement distrust does not
    /// bounce it; never the focus command, whose displacement note
    /// would arm that bounce. A click in the bar chooses nothing —
    /// the bar a reveal shows is macOS's, not the user picking that
    /// app; only a window's own report does (the arm). A click on
    /// the revealed window inside one poll of the bar hiding is
    /// the residue: it reports nothing and is paid over. The
    /// pay-time roster of stand-downs, each dropping the debt: a
    /// commanded focus since, the anchor gone, the bound, an own
    /// window keyed since (a quick-menu row fronting a panel), and
    /// a raise that would switch Desktops (#1345) — asked again
    /// here, since the Desktop may have changed since the report.
    func payMenuBarRevealIfDue() {
        guard let debt = menuBarReveal.debt else { return }
        if let commanded = eventLoop.lastCommandedFocus,
            commanded > debt.commandedAt
        {
            dropMenuBarRevealDebt("a commanded focus since")
            return
        }
        guard state.windows[debt.window] != nil else {
            dropMenuBarRevealDebt("its window closed")
            return
        }
        let age = wallClock().timeIntervalSince(debt.armedAt)
        guard age < Self.menuBarRevealBound else {
            dropMenuBarRevealDebt("past its bound")
            return
        }
        guard !menuBarReveal.statusMenuOpen,
            !mouse.pointerInMenuBarStrip(),
            !mouse.menuOpen(debt.revealedPID)
        else {
            scheduleMenuBarRevealPayment()
            return
        }
        if let key = eventLoop.ownKeyWindow(),
            UInt32(exactly: key.number) != debt.window.raw
        {
            dropMenuBarRevealDebt("an own window keyed since")
            return
        }
        guard !raiseCrossesDesktops(debt.window) else {
            dropMenuBarRevealDebt("not on screen")
            return
        }
        menuBarReveal.debt = nil
        onLog(
            "focus: menu bar hidden; returning w\(debt.window.raw) "
                + "(#1532)"
        )
        if let space = state.workspaces.space(of: debt.window) {
            state.workspaces.focus(debt.window, in: space)
        }
        raiseWindow(debt.window)
        updateBorders()
        updateStickyMarks()
    }

    private func dropMenuBarRevealDebt(_ reason: String) {
        guard let debt = menuBarReveal.debt else { return }
        menuBarReveal.debt = nil
        deferred.cancel(.menuBarRevealReturn)
        onLog(
            "focus: w\(debt.window.raw) reveal return stood down — "
                + reason
        )
    }
}
