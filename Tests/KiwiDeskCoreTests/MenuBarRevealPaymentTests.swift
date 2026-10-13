import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1532 reveal return's PAYMENT (#2224): owed while the bar
/// shows or KiwiDesk's quick menu is open, paid once both are
/// gone, and stood down at pay time by a commanded focus,
/// a closed anchor, the bound, an own window keyed since or a
/// raise that would switch Desktops. The arm is
/// `MenuBarRevealReturnTests`'.
@Suite("Menu-bar reveal payment (#2224)", .serialized)
@MainActor
struct MenuBarRevealPaymentTests {
    private typealias F = MenuBarRevealFixture

    /// Returned at once, macOS took the activation back every
    /// ~1.3 s for as long as the pointer stayed (#2224): nothing is
    /// raised while the bar shows.
    @Test("Nothing is returned while the bar shows")
    func notWhileTheBarShows() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt != nil)
        #expect(!lines.contain("menu bar hidden"))
    }

    @Test("The return is paid once the bar hides")
    func paidOnceTheBarHides() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("menu bar hidden; returning w1"))
        #expect(F.focused(core) == WindowID(1))
    }

    /// The bar a reveal shows is macOS's: opening or picking in
    /// its menus is not the user choosing that app (owner,
    /// 2026-10-13), so the return is still paid.
    @Test("A click in the menu bar keeps the return")
    func barClickKeepsTheReturn() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(1),
            point: .zero,
            reached: nil
        )
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("menu bar hidden; returning w1"))
        #expect(F.focused(core) == WindowID(1))
    }

    @Test("A commanded focus while the return is owed drops it")
    func commandedSinceDrops() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.eventLoop.lastCommandedFocus = .now.advanced(by: .seconds(1))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("a commanded focus since"))
        #expect(!lines.contain("menu bar hidden"))
        // The command chose the focus; nothing is handed back.
        #expect(F.focused(core) == WindowID(1))
    }

    @Test("A return owed past its bound is dropped")
    func pastTheBoundDrops() {
        let core = F.makeCore()
        let lines = F.log(core)
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

    /// KiwiDesk's own quick menu (#2224): the activation that comes
    /// with it is owed like a reveal while the menu is open, wherever
    /// the pointer is, and paid once it closes.
    @Test("The quick menu holds the return until it closes")
    func statusMenuHoldsTheReturn() {
        let core = F.makeCore(inStrip: false)
        core.statusMenuDidOpen()
        core.handle(.windowFocused(WindowID(2)))
        #expect(F.focused(core) == WindowID(1))
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt != nil)
        core.statusMenuDidClose()
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(F.focused(core) == WindowID(1))
    }

    /// The click that closes the quick menu is no choice either.
    @Test("The quick menu's closing click keeps the return")
    func closingClickKeepsTheReturn() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        core.statusMenuDidOpen()
        core.handle(.windowFocused(WindowID(2)))
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(1),
            point: .zero,
            reached: nil
        )
        core.statusMenuDidClose()
        core.payMenuBarRevealIfDue()
        #expect(lines.contain("menu bar hidden; returning w1"))
        #expect(F.focused(core) == WindowID(1))
    }

    /// The reason the re-assert is a stamped raise and not the
    /// focus command: the command's displacement note would put
    /// the foreign window in the placement ledger, and in an
    /// ACTIVE scrolling Space that live entry is the whole #1161
    /// verdict — every later report from that app bounced.
    @Test("In scrolling the return leaves no placement entry")
    func scrollingLeavesNoPlacement() {
        let core = F.makeCore()
        core.state.workspaces.setMode(SpaceID(1), .scrolling)
        core.handle(.windowFocused(WindowID(2)))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(F.focused(core) == WindowID(1))
        #expect(core.tiler.placements.recent(WindowID(2)) == nil)
    }

    /// Every schedule is the debt's only way to be paid: a revert
    /// of any one leaves it owed forever.
    @Test("Each step schedules the next payment")
    func paymentIsScheduled() {
        let core = F.makeCore()
        core.handle(.windowFocused(WindowID(2)))
        #expect(core.deferred.isScheduled(.menuBarRevealReturn))
        core.deferred.cancel(.menuBarRevealReturn)
        core.payMenuBarRevealIfDue()
        #expect(core.deferred.isScheduled(.menuBarRevealReturn))
        core.deferred.cancel(.menuBarRevealReturn)
        core.statusMenuDidOpen()
        core.statusMenuDidClose()
        #expect(core.deferred.isScheduled(.menuBarRevealReturn))
    }

    @Test("A closed anchor drops the return")
    func goneAnchorDrops() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.state.apply(.windowDestroyed(WindowID(1), wasMinimized: false))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("its window closed"))
    }

    /// An open menu keeps the revealed bar up while the pointer
    /// sits in it, below the strip: paying then would close the
    /// menu under the user (#2224).
    @Test("An open menu of the revealed app holds the return")
    func openMenuHoldsTheReturn() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.mouse.pointerInMenuBarStrip = { false }
        core.mouse.menuOpen = { $0 == 99 }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt != nil)
        #expect(!lines.contain("menu bar hidden"))
        #expect(core.deferred.isScheduled(.menuBarRevealReturn))
        core.mouse.menuOpen = { _ in false }
        core.payMenuBarRevealIfDue()
        #expect(lines.contain("menu bar hidden; returning w1"))
    }

    /// The payment can run seconds after the report, so the #1345
    /// gate is asked again at pay time (#2224 review).
    @Test("A payment that would switch Desktops is dropped")
    func crossingPaymentDrops() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.windowIsOnScreen = { $0 != WindowID(1) }
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("not on screen"))
        #expect(!lines.contain("menu bar hidden"))
    }

    /// A quick-menu row that fronts an own panel (View Shortcuts)
    /// keys it without a commanded focus; the payment leaves it.
    @Test("An own window keyed since stands the payment down")
    func ownKeyWindowDrops() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        core.statusMenuDidOpen()
        core.handle(.windowFocused(WindowID(2)))
        core.statusMenuDidClose()
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 999_999, isDialog: false)
        }
        core.payMenuBarRevealIfDue()
        #expect(lines.contain("an own window keyed since"))
        #expect(!lines.contain("menu bar hidden"))
        // The control: the anchor itself key still pays.
        let anchor = F.makeCore(inStrip: false)
        let paid = F.log(anchor)
        anchor.statusMenuDidOpen()
        anchor.handle(.windowFocused(WindowID(2)))
        anchor.statusMenuDidClose()
        anchor.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 1, isDialog: false)
        }
        anchor.payMenuBarRevealIfDue()
        #expect(paid.contain("menu bar hidden"))
    }

    /// A return the open owed over a report ahead of it waits for
    /// the menu to close and is paid then, like one owed at the
    /// report.
    @Test("A return owed at the open is paid at the close")
    func openLookBackPaysAtTheClose() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.statusMenuDidOpen()
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt != nil)
        #expect(!lines.contain("menu bar hidden"))
        core.statusMenuDidClose()
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("menu bar hidden; returning w1"))
        #expect(F.focused(core) == WindowID(1))
    }
}
