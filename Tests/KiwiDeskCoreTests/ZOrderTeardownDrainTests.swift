import Foundation
import Testing

@testable import KiwiDeskCore

/// #688: the quit-grid restack is the one raise sequence nothing
/// runs after, so a miss is the arrangement the user is left
/// looking at. Routing it through the drain made two things the
/// call site's to decide rather than the drain's — its budget, and
/// which windows are even raisable — and this suite prices both.
/// `KiwiCore+TeardownRaise` carries the arguments;
/// `ZOrderSequenceWiringTests` pins that the call site still makes
/// those two choices. Runs against the shared fake WindowServer
/// (`ZOrderDrainFake`), so it reaches no real window.
@Suite("Z-order teardown drain (#688)")
struct ZOrderTeardownDrainTests {

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map(WindowID.init)
    }

    /// What `restackForTeardown` drops the frontmost app's key
    /// window for, priced. That window is `pinned` here; the
    /// measurement behind it and the reasoning are on that
    /// function.
    ///
    /// Kept in the sequence it does not cost its own slot, it
    /// costs everyone above it — a circle that verifies in
    /// milliseconds instead eats the budget and still settles
    /// wrong. Dropped, the same windows verify at once and stand
    /// as the circle asked, because the landing check is relative
    /// and filtered to the drain's own targets.
    @Test("A pinned member makes the rest of a circle unverifiable")
    func aPinnedMemberIsDroppedNotAbsorbed() {
        let circle = ids([5, 4, 3, 2, 1])
        let pinned = WindowID(4)

        func settle(
            _ order: [WindowID]
        ) -> (stacking: [WindowID], spent: TimeInterval) {
            let server = FakeWindowServer(
                order: ids([4, 5, 3, 2, 1]),
                pinned: pinned
            )
            _ = server.teardownDrain().run(order)
            let spent = server.clock
            // Perform whatever is still in flight, so what is
            // compared is where the apps left the pile.
            server.clock += 1
            return (server.stacking(), spent)
        }

        let kept = settle(circle)
        // 4 never moves, so the three windows the circle puts
        // above it all fail, one `landingLimit` each.
        #expect(kept.stacking == ids([4, 1, 2, 3, 5]))
        #expect(kept.spent >= 3 * ZOrderDrain.landingLimit)

        let dropped = settle(circle.filter { $0 != pinned })
        #expect(
            dropped.stacking.filter { $0 != pinned }
                == ids([1, 2, 3, 5])
        )
        #expect(dropped.spent < ZOrderDrain.landingLimit)
    }

    /// The budget is the call site's, and buying more of it buys
    /// real verification — what `ZOrderDrain.Policy.teardown.budget` is
    /// for.
    ///
    /// One circle, two budgets, identical apps. Under teardown's
    /// the circle settles exactly as asked. Under a restore's the
    /// drain runs out mid-circle, and because the teardown
    /// sequence DROPS its tail rather than issuing it unverified
    /// (`spendsBudgetOnUnverifiedTail`), the windows it never
    /// reached keep the places they started in — window 1, which
    /// the circle wanted at the front, is left at the very back.
    /// That is the shape of a quit that ran out of time: not a
    /// near-miss, a circle cut in half.
    ///
    /// Both halves are needed, and both assert an exact stacking
    /// rather than "not the right one". `cut != settled` was the
    /// first draft and it is satisfied by an arbitrarily worse
    /// drain, including one that raises nothing at all
    /// (guard-prover, 2026-08-03) — the array pins which windows
    /// moved and which did not.
    @Test("A bigger budget verifies a longer circle")
    func injectedBudgetDecidesWhatIsVerified() {
        let circle = ids([8, 7, 6, 5, 4, 3, 2, 1])
        let settled = ids([1, 2, 3, 4, 5, 6, 7, 8])

        func settle(under budget: TimeInterval) -> [WindowID] {
            let server = FakeWindowServer(order: circle)
            for id in ids([7, 6, 5, 4, 3]) {
                server.latency[id] = 0.09
            }
            server.latency[WindowID(2)] = 0.01
            server.latency[WindowID(1)] = 0.10
            _ = server.teardownDrain(budget: budget).run(circle)
            // Let every raise still in flight be performed, so
            // what is compared is where the apps left the pile and
            // not merely what had happened by the deadline.
            server.clock += 1
            return server.stacking()
        }

        #expect(
            settle(under: ZOrderDrain.Policy.teardown.budget) == settled
        )
        // 7, 6, 5 and 4 verified; 3 was raised and timed out; 2
        // was raised as the budget ran out; 1 was never reached
        // and stays where the moves left it, at the back.
        #expect(
            settle(under: ZOrderDrain.Policy.restore.budget)
                == ids([3, 2, 4, 5, 6, 7, 8, 1])
        )
    }
}
