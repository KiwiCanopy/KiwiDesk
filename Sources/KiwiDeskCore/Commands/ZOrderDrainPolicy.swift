import Foundation

extension ZOrderDrain {
    /// What one kind of raise sequence is allowed to spend, and
    /// what it does when that is gone.
    ///
    /// **One value per production sequence, named, and the same
    /// value the tests build their fake drains from.** The two
    /// settings were separate parameters first, and both were
    /// hand-copied into `ZOrderDrainFake`'s factories — so the
    /// suite proved what the drain does with a given policy and
    /// never that production hands it the right one. Flipping
    /// either production call site left all 2424 tests green
    /// (guard-prover, 2026-08-03). Bundling them here removes the
    /// mirror instead of netting it: a call site now names a
    /// policy rather than restating its fields, and changing what
    /// `restore` or `teardown` means changes it for the tests in
    /// the same edit.
    ///
    /// Required at every call site, like `floor` — a new sequence
    /// picks one of these or adds its own, deliberately.
    struct Policy: Sendable {
        /// Whole-sequence ceiling. A total, not a per-window sum:
        /// eight windows at `landingLimit` would drain a second.
        let budget: TimeInterval
        /// What a spent budget does to the raises the plan has
        /// left: issue them unverified (true) or drop them
        /// (false).
        let spendsBudgetOnUnverifiedTail: Bool

        /// A live restore: bounded by `zOrderRestoresInFlight`,
        /// which holds the mouse warp for exactly as long as the
        /// drain runs. The budget is ~5x the ~55 ms a verified
        /// 6-window row measured (#684).
        ///
        /// It issues its tail. Its caller stamped every target in
        /// the raise echo ledger, so a dropped raise is both a
        /// window left definitely in the wrong place AND a stamp
        /// nothing consumes — and the cost of issuing is paid on
        /// `zOrderQueue`, not anywhere a user is waiting.
        static let restore = Policy(
            budget: 0.4,
            spendsBudgetOnUnverifiedTail: true
        )

        /// The quit-grid teardown restack: the same 1 s the bare
        /// loop it replaced was capped at, spent across every
        /// display group rather than per group (#688).
        ///
        /// More than a restore's, for the reason the restack is
        /// worth verifying at all — nothing runs after it to heal
        /// a miss, so waiting is worth more there than anywhere
        /// else.
        ///
        /// It drops its tail, which is the only thing that makes
        /// the budget a real ceiling: issuing is not free here.
        /// Each raise is a blocking `AXUIElementPerformAction`
        /// bounded only by the 0.25 s AX messaging timeout, on the
        /// main actor, after the budget is already spent — a
        /// nine-window tail could add seconds to a quit that had
        /// promised to stop at one. The quit path has no echo
        /// ledger to corrupt, so the reason the restores issue
        /// does not apply to it, and a quit that hangs is worse
        /// than a quit that stacks imperfectly (code review,
        /// 2026-08-03).
        ///
        /// Even so the ceiling is the budget plus ONE blocking
        /// raise per display group: `issue` raises before it
        /// checks the clock, the same shape the old loop had.
        static let teardown = Policy(
            budget: 1.0,
            spendsBudgetOnUnverifiedTail: false
        )

        /// The same policy on a shorter clock — the teardown
        /// restack narrowing its whole-quit budget to what one
        /// display group has left of it.
        func limited(to seconds: TimeInterval) -> Policy {
            Policy(
                budget: min(budget, seconds),
                spendsBudgetOnUnverifiedTail:
                    spendsBudgetOnUnverifiedTail
            )
        }
    }
}
