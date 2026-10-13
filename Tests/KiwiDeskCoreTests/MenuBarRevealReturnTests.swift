import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1532 menu-bar reveal return: with the bar auto-hidden,
/// macOS 27 answers the pointer reaching the top edge by
/// activating the last regular app — KiwiDesk is an accessory
/// app — and a clickless foreign focus report lands ~190 ms
/// later. The report is taken and the return OWED until the bar
/// hides or KiwiDesk's quick menu closes (#2224). This suite holds
/// the arm — each let-out at the report (a click on the window,
/// another window, a foreign anchor, a self echo, the pointer
/// elsewhere) is a case
/// below; the payment and its stand-downs are
/// `MenuBarRevealPaymentTests`'. The device evidence is on the
/// issues.
@Suite("Menu-bar reveal return (#1532)", .serialized)
@MainActor
struct MenuBarRevealReturnTests {
    private typealias F = MenuBarRevealFixture

    @Test("The reveal's activation is taken and its return owed")
    func activationIsOwed() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(core) == WindowID(1))
        #expect(lines.contain(F.returnLogNeedle))
        #expect(core.menuBarReveal.debt?.window == WindowID(1))
    }

    @Test("The pointer elsewhere makes it an ordinary focus")
    func pointerAwayIsHonored() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(core) == WindowID(2))
        #expect(!lines.contain(F.returnLogNeedle))
    }

    /// A click into the revealed bar's menus reaches no window and
    /// chooses nothing (owner, 2026-10-13); a click that reached
    /// the reported window is a window choice.
    @Test("Only a click on the reported window is a choice")
    func clickOnTheWindowIsAChoice() {
        let core = F.makeCore()
        // Stamped AHEAD: an "inside the window" verdict measured
        // against the wall clock races a starved runner (#1371).
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(60),
            point: .zero,
            reached: WindowID(2)
        )
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(core) == WindowID(2))
        #expect(!lines.contain(F.returnLogNeedle))
        // The control: the same press in the bar is no choice.
        let bar = F.makeCore()
        bar.lastLeftClick = (
            at: bar.wallClock().addingTimeInterval(60),
            point: .zero,
            reached: nil
        )
        bar.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(bar) == WindowID(1))
        #expect(bar.menuBarReveal.debt != nil)
    }

    /// A lazy app reports a raised window twice (#887): the repeat
    /// is the same reveal, still taken.
    @Test("A repeat of the reveal's report is the same reveal")
    func repeatIsTheSameReveal() {
        let core = F.makeCore()
        core.handle(.windowFocused(WindowID(2)))
        core.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(core) == WindowID(1))
        #expect(core.menuBarReveal.debt != nil)
    }

    /// ⌘-Tab while the bar shows: another window's report is the
    /// user switching, so the debt drops and the report stands.
    @Test("Another window's report is the user switching")
    func anotherWindowDropsTheDebt() {
        let core = F.makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(3), pid: 77, appName: "Third")
            )
        )
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.handle(.windowFocused(WindowID(2)))
        core.handle(.windowFocused(WindowID(3)))
        #expect(F.focused(core) == WindowID(3))
        #expect(core.menuBarReveal.debt == nil)
    }

    /// The #1345 stand-down, beside a shown control: a return
    /// that would switch Desktops is refused and the report
    /// honored, the arm neither owing nor stranding state.
    @Test("A return that crosses Desktops is honored instead")
    func crossingReturnIsHonored() {
        let core = F.makeCore()
        core.windowIsOnScreen = { $0 != WindowID(1) }
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(core) == WindowID(2))
        #expect(!lines.contain(F.returnLogNeedle))
        #expect(lines.contain("#1345"))
        #expect(core.menuBarReveal.debt == nil)
        // The control: shown, the same report is owed.
        let shown = F.makeCore()
        shown.windowIsOnScreen = { _ in true }
        shown.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        shown.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(shown) == WindowID(1))
    }

    @Test("A foreign anchor is never returned to")
    func foreignAnchorIsHonored() {
        // Only an accessory app's window is skipped by the
        // activation; a regular app's focused window is where
        // macOS lands anyway, so there is nothing to return.
        let core = F.makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(3),
                    pid: 77,
                    appName: "Third"
                )
            )
        )
        core.state.workspaces.focus(WindowID(2), in: SpaceID(1))
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(3)))
        #expect(F.focused(core) == WindowID(3))
        #expect(!lines.contain(F.returnLogNeedle))
    }

    @Test("A report for an own window is never returned")
    func ownReportIsNotReturned() {
        let core = F.makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(4),
                    pid: pid_t(ProcessInfo.processInfo.processIdentifier),
                    appName: "KiwiDesk"
                )
            )
        )
        // The create fold focused the newcomer; anchor window 1
        // again so only the pid clause stands between this report
        // and a return (guard-prover, 2026-09-21).
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(4)))
        #expect(F.focused(core) == WindowID(4))
        #expect(!lines.contain(F.returnLogNeedle))
    }

    @Test("Our own raise's echo is not a reveal")
    func selfEchoIsNotReturned() {
        let core = F.makeCore()
        core.selfRaiseStamps[WindowID(2)] =
            core.wallClock().addingTimeInterval(60)
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(!lines.contain(F.returnLogNeedle))
        #expect(core.menuBarReveal.debt == nil)
    }

    /// The quick menu's activation reports AHEAD of `menuWillOpen`,
    /// inside the menu's build (device, 2026-10-13: 52 ms ahead),
    /// so the report is honored at the time and the open owes it.
    @Test("A report ahead of the quick menu's open is owed at the open")
    func reportAheadOfTheOpenIsOwedAtTheOpen() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(core) == WindowID(2))
        #expect(!lines.contain(F.returnLogNeedle))
        core.statusMenuDidOpen()
        #expect(F.focused(core) == WindowID(1))
        #expect(lines.contain(F.returnLogNeedle))
        #expect(core.menuBarReveal.debt?.window == WindowID(1))
    }

    /// A report older than the grace was the user's.
    @Test("A stale report is not owed at the open")
    func staleReportIsNotOwedAtTheOpen() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        let late = core.wallClock().addingTimeInterval(
            KiwiCore.menuBarRevealOpenGrace + 1
        )
        core.wallClock = { late }
        core.statusMenuDidOpen()
        #expect(F.focused(core) == WindowID(2))
        #expect(!lines.contain(F.returnLogNeedle))
        #expect(core.menuBarReveal.debt == nil)
    }

    /// The revealed window may sit in another Space — its report
    /// switches nothing and leaves the active Space's focus on the
    /// anchor (device, 2026-10-13) — and the open still owes it.
    @Test("A revealed window in another Space is owed at the open")
    func otherSpaceReportIsOwedAtTheOpen() {
        let core = F.makeCore(inStrip: false)
        core.state.workspaces.add(WindowID(2), to: SpaceID("2"))
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(!lines.contain(F.returnLogNeedle))
        core.statusMenuDidOpen()
        #expect(lines.contain(F.returnLogNeedle))
        #expect(core.menuBarReveal.debt?.window == WindowID(1))
        #expect(F.focused(core) == WindowID(1))
    }

    /// A lazy app's duplicate of the declined report (#887) keeps
    /// the candidate for the open.
    @Test("A repeat of the declined report keeps it for the open")
    func repeatKeepsTheDeclinedReport() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.handle(.windowFocused(WindowID(2)))
        core.statusMenuDidOpen()
        #expect(lines.contain(F.returnLogNeedle))
        #expect(core.menuBarReveal.debt?.window == WindowID(1))
    }

    /// A window honored after the declined report is the user's
    /// choice; the open owes nothing over it.
    @Test("A later choice is not owed at the open")
    func laterChoiceIsNotOwedAtTheOpen() {
        let core = F.makeCore(inStrip: false)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(3), pid: 98, appName: "Third")
            )
        )
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.handle(.windowFocused(WindowID(3)))
        core.statusMenuDidOpen()
        #expect(F.focused(core) == WindowID(3))
        #expect(!lines.contain(F.returnLogNeedle))
        #expect(core.menuBarReveal.debt == nil)
    }
}
