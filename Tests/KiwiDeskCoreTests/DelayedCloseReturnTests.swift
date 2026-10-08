import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The delayed-close return (#2002): a close the #1157 distrust
/// refused is confirmed only after macOS keyed the app's window
/// on another Space and our follow switched there; the heal runs
/// the #936 close-return as if the removal had landed when the
/// episode opened. Driven through `handle` in the issue's log
/// order — refusal, same-app focus honored, follow, confirmation.
/// The let-outs no stand-down reason names are
/// `DelayedCloseLetOutTests`'; the topology override's safety is
/// argued on `DelayedCloseFixture.confirmClose`.
@Suite("Delayed close return (#2002)", .serialized)
@MainActor
struct DelayedCloseReturnTests {
    let fx = DelayedCloseFixture()

    @Test("A delayed close returns to its Space's fallback")
    func delayedCloseReturns() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        fx.confirmClose(core)
        fx.expectReturned(core, log)
        #expect(log.has("return owed in space 1"))
        #expect(core.delayedCloseDebt == nil)
    }

    /// The real follow: its deferred gate reads the frontmost app
    /// and the app's focused window through their seams.
    @Test("The follow landed through the deferred queue is honored")
    func deferredFollowReturns() async throws {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        core.frontmostPIDProvider = { [app = fx.app] in app }
        core.eventLoop.shadows.focusedWindow = {
            [successor = fx.successor] _ in successor
        }
        fx.refuse(core)
        core.handle(.windowFocused(fx.successor))
        // The follow's own handle, awaited — never a wall-clock poll,
        // which a starved main actor outlives (tests.md, #344).
        let follow = try #require(core.deferred.task(for: .focusFollow))
        await follow.value
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.delayedCloseDebt?.followed == true)
        fx.confirmClose(core)
        fx.expectReturned(core, log)
    }

    @Test("Scrolling: the owed switch retiles once, the raise none")
    func scrollingRetilesOnce() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        core.setSpaceMode("1", .scrolling)
        fx.refuse(core)
        fx.keySuccessor(core)
        let meter = WorkMeter()
        core.tiler.meter = meter
        fx.confirmClose(core)
        fx.expectReturned(core, log)
        // The destroy's own event pass, then the switch's.
        #expect(meter.snapshot(reset: false).counts.retiles == 2)
    }

    @Test("An owed Space with no fallback stands the return down")
    func emptySpaceStandsDown() {
        let (core, log) = fx.makeCore(fallback: false)
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("stood down (no raisable fallback)"))
    }

    @Test("A fullscreen fallback stands the return down")
    func fullscreenFallbackStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        core.state.windows.setFullscreen(fx.fallback, true)
        fx.refuse(core)
        fx.keySuccessor(core)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("stood down (no raisable fallback)"))
    }

    /// The tail's own verdict outranks the heal: an own dialog key
    /// stands the raise down, and with it the owed switch.
    @Test("The close-return stand-down keeps the user where they are")
    func tailStandDownKeepsTheSpace() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 7, isDialog: true)
        }
        fx.refuse(core)
        fx.keySuccessor(core)
        fx.confirmClose(core)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(!log.has("close-return: raising"))
        #expect(log.has("standsDown=true"))
    }

    @Test("A press during the episode stands the return down")
    func pressStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        core.lastLeftClick = (core.wallClock(), .zero, nil)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("return stood down (a press)"))
    }

    @Test("A commanded focus during the episode stands it down")
    func commandStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        core.eventLoop.lastCommandedFocus =
            ContinuousClock.now.advanced(by: .milliseconds(5))
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("return stood down (a commanded focus)"))
    }

    /// The user's own switch to the successor's Space beats the
    /// follow there, which then stands down: no follow, no debt.
    @Test("A user Space switch before the follow stands it down")
    func userSwitchStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core, follow: false)
        core.switchSpace(to: "2", warp: false)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("return stood down (no follow of the successor)"))
    }

    @Test("A Space switch after the follow landed stands it down")
    func switchAfterFollowStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        core.switchSpace(to: "3", warp: false)
        fx.confirmClose(core)
        #expect(core.state.workspaces.activeSpace == "3")
        #expect(!log.has("close-return: raising"))
        #expect(log.has("return stood down (focus moved on)"))
    }

    @Test("A confirmation past the bound stands it down")
    func expiredStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        let late = core.wallClock().addingTimeInterval(
            core.delayedCloseBound + 0.1
        )
        core.wallClock = { late }
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("return stood down (expired)"))
    }
}
