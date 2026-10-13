import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1532 reveal return's PAYMENT (#2224): owed while the bar
/// shows or KiwiDesk's quick menu is open, paid once both are
/// gone, and stood down at pay time by a press, a commanded focus,
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

    @Test("A press while the return is owed drops it")
    func pressSinceDrops() {
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
        #expect(lines.contain("stood down — a press since"))
        #expect(!lines.contain("menu bar hidden"))
        // The report the arm held back is honored, or state focus
        // stays on a window macOS no longer keys.
        #expect(F.focused(core) == WindowID(2))
        #expect(lines.contain(F.honoredNeedle))
        #expect(!core.deferred.isScheduled(.menuBarRevealReturn))
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
        #expect(F.focused(core) == WindowID(2))
        #expect(lines.contain(F.honoredNeedle))
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

    /// The click that dismisses the quick menu never reaches the
    /// app beneath it, so it stands nothing down (#2224).
    @Test("The quick menu's dismissing click is no choice")
    func dismissingClickIsNoChoice() {
        let core = F.makeCore(inStrip: false)
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
        #expect(F.focused(core) == WindowID(1))
        let lines = F.log(core)
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

    @Test("A closed anchor drops the return and honors the report")
    func goneAnchorDrops() {
        let core = F.makeCore()
        let lines = F.log(core)
        core.handle(.windowFocused(WindowID(2)))
        core.state.apply(.windowDestroyed(WindowID(1), wasMinimized: false))
        core.mouse.pointerInMenuBarStrip = { false }
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(lines.contain("its window closed"))
        #expect(F.focused(core) == WindowID(2))
        #expect(lines.contain(F.honoredNeedle))
    }

    /// The bound runs from the report, never from the quick
    /// menu's close, which moves only the press baseline.
    @Test("The bound runs from the report")
    func boundRunsFromTheReport() {
        let core = F.makeCore(inStrip: false)
        let lines = F.log(core)
        let start = core.wallClock()
        core.statusMenuDidOpen()
        core.handle(.windowFocused(WindowID(2)))
        core.wallClock = { start.addingTimeInterval(20) }
        core.statusMenuDidClose()
        core.wallClock = { start.addingTimeInterval(35) }
        core.payMenuBarRevealIfDue()
        #expect(lines.contain("past its bound"))
        #expect(!lines.contain("menu bar hidden"))
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
        #expect(F.focused(core) == WindowID(2))
        #expect(lines.contain(F.honoredNeedle))
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

    /// The replay is the handler's honor, warp aside: the user's
    /// hand is on the revealed app's bar, not on its window.
    @Test("A stand-down's replay moves no pointer")
    func replayMovesNoPointer() {
        // Slot resolution needs a real screen; a screenless
        // runner skips (the screen-guard convention).
        guard NSScreen.main != nil else { return }
        let core = F.makeCore()
        core.tiler.settings.mouse.followsFocus = true
        var warped: [CGRect] = []
        core.pointerWarp = { warped.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(1),
            point: .zero,
            reached: nil
        )
        core.payMenuBarRevealIfDue()
        #expect(F.focused(core) == WindowID(2))
        #expect(warped.isEmpty)
        // The control: the same report honored outright warps.
        let plain = F.makeCore(inStrip: false)
        plain.tiler.settings.mouse.followsFocus = true
        var moved: [CGRect] = []
        plain.pointerWarp = { moved.append($0) }
        plain.handle(.windowFocused(WindowID(2)))
        #expect(moved.count == 1)
    }

    /// A press while the bar still shows: the replayed report
    /// meets the arm again, which stands aside for it.
    @Test("A replay is never taken as a fresh reveal")
    func replayIsNotRetaken() {
        let core = F.makeCore()
        let lines = F.log(core)
        let start = core.wallClock()
        core.handle(.windowFocused(WindowID(2)))
        // A press since the report, but outside the echo window by
        // the time the payment polls: only the replay guard keeps
        // the arm from taking the replay as a new reveal.
        core.lastLeftClick = (
            at: start.addingTimeInterval(1),
            point: .zero,
            reached: nil
        )
        core.wallClock = { start.addingTimeInterval(10) }
        #expect(!core.recentLeftPress(now: core.wallClock()))
        core.payMenuBarRevealIfDue()
        #expect(core.menuBarReveal.debt == nil)
        #expect(F.focused(core) == WindowID(2))
        #expect(lines.contain(F.honoredNeedle))
    }
}
