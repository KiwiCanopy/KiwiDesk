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
            _ = server.drain().run(order)
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
    /// real verification — what `teardownRaiseBudget` is for.
    ///
    /// One circle, two budgets, identical apps. Under the restore
    /// budget the tail runs out of time and goes out unverified,
    /// so the apps land it in latency order instead of raise
    /// order. Under teardown's it settles exactly as asked.
    ///
    /// Both halves are needed: the correct one alone passes
    /// against a drain that ignores the budget, the scrambled one
    /// alone against a drain whose budget is always tiny.
    ///
    /// But read the scrambled half narrowly, because it is
    /// satisfied by an arbitrarily WORSE drain — including one
    /// that raises nothing at all (guard-prover, 2026-08-03). Its
    /// green means "not fully verified", never "verified the right
    /// amount". A no-op drain is caught by
    /// `aPinnedMemberIsDroppedNotAbsorbed`, which asserts the
    /// stacking it produces rather than only that it differs. The
    /// `3` before `2` check is a strengthening of that half —
    /// naming WHICH scramble — not a second net: 2 is the fastest
    /// app in the fixture, so any budget that lets it land behind
    /// 3 also settles the whole circle and reds the first half.
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
            _ = server.drain(budget: budget).run(circle)
            // Let every raise still in flight be performed, so
            // what is compared is where the apps left the pile and
            // not merely what had happened by the deadline.
            server.clock += 1
            return server.stacking()
        }

        #expect(
            settle(under: KiwiCore.teardownRaiseBudget) == settled
        )
        let cut = settle(under: ZOrderDrain.restoreBudget)
        #expect(cut != settled)
        #expect(
            cut.firstIndex(of: WindowID(3)).map({ index in
                index < (cut.firstIndex(of: WindowID(2)) ?? -1)
            }) == true
        )
    }
}
