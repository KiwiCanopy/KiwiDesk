import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The hand-back `open_in_background` owes (#3141 ▸ Ruling): the
/// focus a background-opened app takes is handed back once per app,
/// at whichever door comes first, the app's activation or the focus
/// report of its tracked window, and a second take is the app's.
/// Each let-out sits beside the paid case it differs from by one
/// input.
@Suite("open_in_background hands the focus back once (#3141)", .serialized)
@MainActor
struct OpenInBackgroundHoldTests {
    typealias F = OpenInBackgroundTests

    static func activate(_ core: KiwiCore, _ bundleID: String = F.app) {
        core.noteAppActivation(
            AppActivation(pid: 900_400, bundleID: bundleID, launchedAt: nil),
            now: core.wallClock()
        )
    }

    static func capture(_ core: KiwiCore) -> () -> [String] {
        final class Box { var lines: [String] = [] }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        return { box.lines }
    }

    static let handedBack =
        "open_in_background: \(F.app) took the focus — handed back to w1"

    // MARK: The report door

    @Test("a focus report of its window is handed back, then kept")
    func reportHandedBackOnce() {
        let core = F.taken()
        let log = Self.capture(core)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(1))
        #expect(log().contains(Self.handedBack))
        #expect(core.launchFollow.holds.opened.isEmpty)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
    }

    /// The #1161 bounce would otherwise re-assert the second take.
    @Test("the hand-back drops the app's windows from the placement ledger")
    func handBackForgetsPlacements() {
        let core = F.taken()
        core.tiler.placements.noteDisplaced(WindowID(7), frame: .zero)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.tiler.placements.recent(WindowID(7)) == nil)
    }

    @Test("a click on the app's window keeps the focus there")
    func clickKeeps() {
        let core = F.taken()
        let log = Self.capture(core)
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(7))
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
        #expect(log().contains("open_in_background: w7 keeps the focus"))
        #expect(core.launchFollow.holds.opened.isEmpty)
    }

    /// The user working on in their own window stops nothing.
    @Test("a click in the user's own window still hands back")
    func ownClickHandsBack() {
        let core = F.taken()
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(1))
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("past the grace the take is kept")
    func lateTakeKept() {
        let core = F.taken()
        let late = core.wallClock().addingTimeInterval(
            BackgroundHolds.grace + 1
        )
        core.wallClock = { late }
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
    }

    @Test("another app's activation leaves the hold standing")
    func otherActivationLeavesHold() {
        let core = F.taken()
        Self.activate(core, F.other)
        #expect(core.launchFollow.holds.opened[F.app] != nil)
    }

    @Test("two opens in a row each hand the focus back")
    func runOfOpens() {
        let core = F.taken()
        #expect(F.open(core, F.other).isSuccess)
        F.arrive(8, bundleID: F.other, on: core)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(1))
        core.handle(.windowFocused(WindowID(8)))
        #expect(core.focusedWindowID == WindowID(1))
    }

    /// Each app's grace runs from its own open.
    @Test("a later open does not stretch an earlier app's grace")
    func perAppGrace() {
        let core = F.taken()
        let start = core.wallClock()
        core.wallClock = { start.addingTimeInterval(8) }
        #expect(F.open(core, F.other).isSuccess)
        core.wallClock = { start.addingTimeInterval(11) }
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
    }

    // MARK: The activation door

    /// A launch's first window is adopted late (#1599): the
    /// activation comes with nothing of the app tracked yet.
    @Test("an activation before its window is adopted is handed back")
    func activationBeforeAdoption() {
        let (core, _) = F.makeCore()
        #expect(F.open(core).isSuccess)
        let log = Self.capture(core)
        Self.activate(core)
        #expect(log().contains(Self.handedBack))
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.launchFollow.holds.opened.isEmpty)
    }

    @Test("a click outside the user's window keeps the activation")
    func dockClickKeeps() {
        let (core, _) = F.makeCore()
        #expect(F.open(core).isSuccess)
        let log = Self.capture(core)
        core.lastLeftClick = (core.wallClock(), .zero, nil)
        Self.activate(core)
        #expect(!log().contains(Self.handedBack))
        #expect(log().contains("open_in_background: \(F.app) keeps the focus"))
    }

    @Test("a click in the user's own window still hands the activation back")
    func ownClickHandsActivationBack() {
        let (core, _) = F.makeCore()
        #expect(F.open(core).isSuccess)
        let log = Self.capture(core)
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(1))
        Self.activate(core)
        #expect(log().contains(Self.handedBack))
    }

    @Test("a report after the activation's hand-back is the app's")
    func doorsShareOneClaim() {
        let core = F.taken()
        Self.activate(core)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
    }
}
