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
/// hides or KiwiDesk's quick menu closes (#2224); each let-out (a
/// press, a commanded focus, the bound, another window, a foreign
/// anchor, a self echo, the pointer elsewhere) is a case below.
/// The device evidence is on the issues.
@Suite("Menu-bar reveal return (#1532)", .serialized)
@MainActor
struct MenuBarRevealReturnTests {
    /// The return's log phrase, asserted POSITIVELY on a return
    /// and NEGATIVELY on the silent let-outs — one constant, so
    /// a reword of the production line reds the positive half
    /// instead of leaving the negative one vacuously green.
    private static let returnLogNeedle = "menu-bar reveal activation"

    /// Windows 1 (OUR pid — the anchor) and 2 (a foreign regular
    /// app), window 1 focused, the pointer read pinned IN the
    /// strip: the reveal's shape.
    private func makeCore(inStrip: Bool = true) -> KiwiCore {
        let core = makeTestCore()
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: own,
                    appName: "KiwiDesk"
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 99,
                    appName: "Other"
                )
            )
        )
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.mouse.pointerInMenuBarStrip = { inStrip }
        return core
    }

    private func focused(_ core: KiwiCore) -> WindowID? {
        core.state.workspaces[SpaceID(1)]?.focused
    }

    private func log(_ core: KiwiCore) -> Lines {
        let lines = Lines()
        core.onLog = { lines.all.append($0) }
        return lines
    }

    private final class Lines {
        var all: [String] = []
        func contain(_ text: String) -> Bool {
            all.contains { $0.contains(text) }
        }
    }

    @Test("The reveal's activation is taken and its return owed")
    func activationIsOwed() {
        let core = makeCore()
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(1))
        #expect(lines.contain(Self.returnLogNeedle))
        #expect(core.menuBarReveal.debt?.window == WindowID(1))
    }

    /// Returned at once, macOS took the activation back every
    /// ~1.3 s for as long as the pointer stayed (#2224): nothing is
    /// raised while the bar shows.
    @Test("Nothing is returned while the bar shows")
    func notWhileTheBarShows() {
        let core = makeCore()
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt != nil)
        #expect(!lines.contain("menu bar hidden"))
    }

    @Test("The return is paid once the bar hides")
    func paidOnceTheBarHides() {
        let core = makeCore()
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("menu bar hidden; returning w1"))
        #expect(focused(core) == WindowID(1))
    }

    @Test("The pointer elsewhere makes it an ordinary focus")
    func pointerAwayIsHonored() {
        let core = makeCore(inStrip: false)
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
        #expect(!lines.contain(Self.returnLogNeedle))
    }

    @Test("A left press anywhere is the user choosing")
    func recentPressStandsDown() {
        // A click into the revealed bar's menus reaches no
        // managed window, so the stand-down is ANY press, not a
        // press that reached the reported window.
        let core = makeCore()
        // Stamped AHEAD: an "inside the window" verdict measured
        // against the wall clock races a starved runner (#1371).
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(60),
            point: .zero,
            reached: nil
        )
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
        #expect(!lines.contain(Self.returnLogNeedle))
    }

    @Test("A press while the return is owed drops it")
    func pressSinceDrops() {
        let core = makeCore()
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(1),
            point: .zero,
            reached: nil
        )
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("stood down — a press since"))
        #expect(!lines.contain("menu bar hidden"))
    }

    @Test("A commanded focus while the return is owed drops it")
    func commandedSinceDrops() {
        let core = makeCore()
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.eventLoop.lastCommandedFocus = .now.advanced(by: .seconds(1))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("a commanded focus since"))
        #expect(!lines.contain("menu bar hidden"))
    }

    @Test("A return owed past its bound is dropped")
    func pastTheBoundDrops() {
        let core = makeCore()
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        let late = core.wallClock().addingTimeInterval(
            KiwiCore.menuBarRevealBound + 1
        )
        core.wallClock = { late }
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("past its bound"))
    }

    /// A lazy app reports a raised window twice (#887): the repeat
    /// is the same reveal, still taken.
    @Test("A repeat of the reveal's report is the same reveal")
    func repeatIsTheSameReveal() {
        let core = makeCore()
        core.handle(.windowFocused(WindowID(2)))
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(1))
        #expect(core.menuBarReveal.debt != nil)
    }

    /// ⌘-Tab while the bar shows: another window's report is the
    /// user switching, so the debt drops and the report stands.
    @Test("Another window's report is the user switching")
    func anotherWindowDropsTheDebt() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(3), pid: 77, appName: "Third")
            )
        )
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.handle(.windowFocused(WindowID(2)))
        core.handle(.windowFocused(WindowID(3)))
        #expect(focused(core) == WindowID(3))
        #expect(core.menuBarReveal.debt == nil)
    }

    /// KiwiDesk's own quick menu (#2224): the activation that comes
    /// with it is owed like a reveal while the menu is open, wherever
    /// the pointer is, and paid once it closes.
    @Test("The quick menu holds the return until it closes")
    func statusMenuHoldsTheReturn() {
        let core = makeCore(inStrip: false)
        core.statusMenuDidOpen()
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(1))
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt != nil)
        core.statusMenuDidClose()
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(focused(core) == WindowID(1))
    }

    /// The click that dismisses the quick menu never reaches the
    /// app beneath it, so it stands nothing down (#2224).
    @Test("The quick menu's dismissing click is no choice")
    func dismissingClickIsNoChoice() {
        let core = makeCore(inStrip: false)
        core.statusMenuDidOpen()
        core.handle(.windowFocused(WindowID(2)))
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(0.1),
            point: .zero,
            reached: nil
        )
        core.statusMenuDidClose()
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(focused(core) == WindowID(1))
        let lines = log(core)
        // A click after the close is a choice again.
        core.lastLeftClick = nil
        core.statusMenuDidOpen()
        core.handle(.windowFocused(WindowID(2)))
        core.statusMenuDidClose()
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(
                KiwiCore.statusMenuCloseGrace + 1
            ),
            point: .zero,
            reached: nil
        )
        core.payMenuBarRevealIfDue()
        #expect(lines.contain("a press since"))
    }

    /// The reason the re-assert is a stamped raise and not the
    /// focus command: the command's displacement note would put
    /// the foreign window in the placement ledger, and in an
    /// ACTIVE scrolling Space that live entry is the whole #1161
    /// verdict — every later report from that app bounced.
    @Test("In scrolling the return leaves no placement entry")
    func scrollingLeavesNoPlacement() {
        let core = makeCore()
        core.state.workspaces.setMode(SpaceID(1), .scrolling)
        core.handle(.windowFocused(WindowID(2)))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(focused(core) == WindowID(1))
        #expect(core.tiler.placements.recent(WindowID(2)) == nil)
    }

    /// The #1345 stand-down, beside a shown control: a return
    /// that would switch Desktops is refused and the report
    /// honored, the arm neither owing nor stranding state.
    @Test("A return that crosses Desktops is honored instead")
    func crossingReturnIsHonored() {
        let core = makeCore()
        core.windowIsOnScreen = { $0 != WindowID(1) }
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
        #expect(!lines.contain(Self.returnLogNeedle))
        #expect(lines.contain("#1345"))
        #expect(core.menuBarReveal.debt == nil)
        // The control: shown, the same report is owed.
        let shown = makeCore()
        shown.windowIsOnScreen = { _ in true }
        shown.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        shown.handle(.windowFocused(WindowID(2)))
        #expect(focused(shown) == WindowID(1))
    }

    @Test("A foreign anchor is never returned to")
    func foreignAnchorIsHonored() {
        // Only an accessory app's window is skipped by the
        // activation; a regular app's focused window is where
        // macOS lands anyway, so there is nothing to return.
        let core = makeCore()
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
        let lines = log(core)
        core.handle(.windowFocused(WindowID(3)))
        #expect(focused(core) == WindowID(3))
        #expect(!lines.contain(Self.returnLogNeedle))
    }

    @Test("A report for an own window is never returned")
    func ownReportIsNotReturned() {
        let core = makeCore()
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
        let lines = log(core)
        core.handle(.windowFocused(WindowID(4)))
        #expect(focused(core) == WindowID(4))
        #expect(!lines.contain(Self.returnLogNeedle))
    }

    @Test("Our own raise's echo is not a reveal")
    func selfEchoIsNotReturned() {
        let core = makeCore()
        core.selfRaiseStamps[WindowID(2)] =
            core.wallClock().addingTimeInterval(60)
        let lines = log(core)
        core.handle(.windowFocused(WindowID(2)))
        #expect(!lines.contain(Self.returnLogNeedle))
        #expect(core.menuBarReveal.debt == nil)
    }
}
