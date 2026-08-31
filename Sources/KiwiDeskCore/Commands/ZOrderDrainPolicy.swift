import Foundation

extension ZOrderDrain {
    /// Time budget and tail handling policy for raise sequences
    /// (`ZOrderDrainFake`, guard-prover 2026-08-03).
    struct Policy: Sendable {
        /// Whole-sequence time ceiling.
        let budget: TimeInterval
        /// Whether remaining raises issue unverified after budget exhaustion.
        let spendsBudgetOnUnverifiedTail: Bool

        /// Live restore policy
        /// (`zOrderRestoresInFlight`, `zOrderQueue`, #684).
        static let restore = Policy(
            budget: 0.4,
            spendsBudgetOnUnverifiedTail: true
        )

        /// Teardown restack policy for application termination
        /// (#688, code review 2026-08-03).
        static let teardown = Policy(
            budget: 1.0,
            spendsBudgetOnUnverifiedTail: false
        )

        /// Clamps policy budget to remaining time.
        func limited(to seconds: TimeInterval) -> Policy {
            Policy(
                budget: min(budget, seconds),
                spendsBudgetOnUnverifiedTail:
                    spendsBudgetOnUnverifiedTail
            )
        }
    }
}
