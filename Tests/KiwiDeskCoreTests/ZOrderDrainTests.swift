import Foundation
import Testing

@testable import KiwiDeskCore

/// #684: `AXUIElementPerformAction(kAXRaiseAction)` returns before
/// a slow app has performed the raise, so a sequence issued back
/// to back settles in whatever order the apps get to it.
/// `ZOrderDrain`'s docstring carries the measurements and the
/// dates; they are not repeated here.
///
/// The drain's every machine effect is a seam, so the whole loop
/// runs here against a fake WindowServer whose apps perform their
/// raises late on a fake clock: no AX, no `CGWindowList`, no
/// wall-clock sleeping. Nothing in this suite may reach the
/// machine — a test that raises a REAL window would reorder the
/// developer's desktop on every `swift test`.
@Suite("Z-order drain (#684)")
struct ZOrderDrainTests {

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map(WindowID.init)
    }

    // MARK: - The floor

    /// The landing check knows about the floor too, not just the
    /// plan (`ZOrderRaisePlanTests` owns that half): without it
    /// the first raise of a sequence verifies against an empty set
    /// and returns instantly, which is the slot the measured
    /// failure lives in.
    ///
    /// The focused window (7) is pinned frontmost here because a
    /// quiet raise cannot beat the key window on a real machine.
    /// It is deliberately NOT in the floor: asking the floats to
    /// clear it would be a condition no raise can satisfy, and
    /// the drain would spend its whole budget failing it on every
    /// focus change.
    @Test("The drain waits for a raise to clear the floor")
    func drainWaitsForTheFloor() {
        let server = FakeWindowServer(
            order: ids([7, 9, 1, 2]),
            pinned: WindowID(7)
        )
        server.latency[WindowID(2)] = 0.06
        let drain = server.drain(above: ids([9]))
        drain.run(ids([2, 1]))
        #expect(server.stacking() == ids([7, 1, 2, 9]))
        #expect(server.raised == ids([2, 1]))
    }

    /// The floor a raise CANNOT clear is the failure this models:
    /// with the key window in the floor, every poll fails and the
    /// drain burns its budget on a sequence that can never verify.
    /// The bound is what keeps that survivable — but the real fix
    /// is that `raiseFloatsAndSticky` leaves the focused window
    /// out of the floor.
    @Test("An unreachable floor still ends inside the budget")
    func unreachableFloorStaysBounded() {
        let server = FakeWindowServer(
            order: ids([7, 1, 2]),
            pinned: WindowID(7)
        )
        let drain = server.drain(above: ids([7]))
        let raised = drain.run(ids([2, 1]))
        // Both halves: it really did the work (a drain that ran
        // nothing would satisfy the bound trivially), and it
        // reports the raises so their stamps are not dropped
        // while the echoes are still coming.
        #expect(raised == ids([2, 1]))
        #expect(
            server.clock
                <= ZOrderDrain.restoreBudget + ZOrderDrain.pollInterval
        )
    }

    // MARK: - The drain

    /// The bug itself: apps that perform the raise long after the
    /// call returns, and in the wrong order relative to each
    /// other. Waiting for each landing is the only thing that
    /// makes the result the order that was asked for — issue them
    /// back to back on this fake and the clock never advances, so
    /// not one of them lands.
    @Test("Raises land in the order they were issued")
    func lateAppsStillLandInOrder() {
        let server = FakeWindowServer(order: ids([4, 3, 2, 1]))
        // Obsidian-shaped: an order of magnitude slower than the
        // rest, and raised first, which is the case that broke.
        server.latency[WindowID(3)] = 0.08
        let drain = server.drain()
        drain.run(ids([4, 3, 2, 1]))
        #expect(server.stacking() == ids([1, 2, 3, 4]))
        #expect(server.raised == ids([3, 2, 1]))
    }

    /// One wedged app must not stall the windows behind it in the
    /// sequence: its raise is given the per-window limit and then
    /// the drain moves on.
    @Test("A window that never lands is skipped, not waited on")
    func wedgedWindowIsSkipped() {
        let server = FakeWindowServer(order: ids([4, 3, 2, 1]))
        server.latency[WindowID(3)] = .infinity
        let drain = server.drain()
        drain.run(ids([4, 3, 2, 1]))
        #expect(server.raised.contains(WindowID(1)))
        #expect(server.raised.contains(WindowID(2)))
        // It is not retried — a second raise inside one sequence
        // strands focus, see `neverRaisesAWindowTwice` — so it
        // stays where it is, and the windows that do answer still
        // stand in order among themselves. The next restore
        // diffs against reality and picks it up.
        #expect(
            server.stacking().filter { $0 != WindowID(3) }
                == ids([1, 2, 4])
        )
    }

    /// The budget is a total, not a per-window sum: eight windows
    /// at the per-window limit would drain a second, and the
    /// in-flight bracket that holds the mouse warp is up for
    /// exactly as long as the drain. Past it the remaining raises
    /// are issued unverified rather than dropped — unverified is
    /// what every pile did before this drain, while a dropped
    /// raise leaves a window definitely in the wrong place.
    @Test("The total budget still issues every raise")
    func exhaustedBudgetIssuesTheRemainder() {
        let order = ids([8, 7, 6, 5, 4, 3, 2, 1])
        let server = FakeWindowServer(order: order)
        for id in order { server.latency[id] = .infinity }
        let drain = server.drain()
        let raised = drain.run(order)
        // Window 8 belongs at the back and is already there, so
        // the plan is the other seven — every one of them issued,
        // none dropped, inside the total budget.
        #expect(Set(server.raised) == Set(order.dropFirst()))
        // And the unverified tail is REPORTED as raised, not just
        // issued: its echoes are still coming, so a caller that
        // dropped those stamps would let one move the ring onto a
        // pile-mate.
        #expect(Set(raised) == Set(server.raised))
        // A poll interval of slack: the fake clock accumulates in
        // 5 ms steps, so it lands ON the limit, not before it.
        #expect(
            server.clock
                <= ZOrderDrain.restoreBudget + ZOrderDrain.pollInterval
        )
    }

    /// **No window is raised twice in one sequence**, whatever the
    /// apps do — the invariant that keeps focus where the user put
    /// it. `zOrderRaiseEchoes` consumes a window's stamp on its
    /// FIRST raise echo, so a second raise inside one sequence
    /// emits an echo nothing reverts and it reads as a deliberate
    /// focus change; the last window raised is the one next to the
    /// focus, so the row pans one slot after every restore (owner
    /// QA, 2026-08-02, on a retry pass that has since been
    /// removed). Both shapes that could re-raise are exercised
    /// here: an app that answers late, and one that never answers.
    @Test("No window is raised twice in one sequence")
    func neverRaisesAWindowTwice() {
        for latency in [0.2, TimeInterval.infinity] {
            let server = FakeWindowServer(order: ids([4, 3, 2, 1]))
            server.latency[WindowID(2)] = latency
            let drain = server.drain()
            drain.run(ids([4, 3, 2, 1]))
            // Non-empty first: `Set(raised).count == raised.count`
            // is also true of a drain that raised nothing, so
            // without this the guard passes on the very failure
            // every other test here would catch (guard-prover,
            // 2026-08-02).
            #expect(!server.raised.isEmpty)
            #expect(
                Set(server.raised).count == server.raised.count
            )
        }
    }

    /// An empty stacking read is the WindowServer query failing,
    /// not a screen with no windows — the drain is here to raise
    /// windows that exist. Diffing against it would drop every
    /// raise silently for as long as the read failed, so the
    /// sequence falls back to issuing them unverified, which is
    /// what every pile did before this drain existed.
    @Test("A failed stacking read still issues every raise")
    func emptyReadFallsBackToUnverified() {
        let server = FakeWindowServer(order: [])
        let drain = server.drain()
        let order = ids([3, 2, 1])
        #expect(drain.run(order) == order)
        #expect(server.raised == order)
    }

    /// A duplicate id would make every tail check fail, so `plan`
    /// would hand the same window back twice and the loop would
    /// raise it twice — the focus slide, arriving through a
    /// caller's bug rather than this loop's. No caller can produce
    /// one today; the loop does not depend on that.
    @Test("A duplicated target is still raised only once")
    func duplicateTargetIsRaisedOnce() {
        let server = FakeWindowServer(order: ids([3, 2, 1]))
        let drain = server.drain()
        _ = drain.run(ids([3, 2, 2, 1]))
        #expect(!server.raised.isEmpty)
        #expect(Set(server.raised).count == server.raised.count)
    }

    /// A jump landing mid-drain supersedes the sequence: it must
    /// abandon the raises it has left rather than finish them and
    /// fight the newer one.
    @Test("A superseded drain abandons its remaining raises")
    func supersededDrainStops() {
        let server = FakeWindowServer(order: ids([4, 3, 2, 1]))
        server.currentUntilRaises = 2
        let drain = server.drain()
        drain.run(ids([4, 3, 2, 1]))
        #expect(server.raised == ids([3, 2]))
    }
}
