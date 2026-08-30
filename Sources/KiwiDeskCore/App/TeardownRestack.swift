import Foundation

/// Controls verified quit-grid raise sequencing across display
/// groups (#688). Main-actor bound, deliberately unlike
/// `ZOrderDrain`: this runs entirely inside the quit path, and
/// marking it `Sendable` would force its seams to give up their
/// access to `KiwiCore`.
@MainActor
struct TeardownRestack {
    /// Whether process holds Accessibility trust.
    let isTrusted: () -> Bool
    /// Frontmost app key window that quiet raises cannot beat.
    let unbeatable: () -> WindowID?
    /// Monotonic clock provider (seconds).
    let now: () -> TimeInterval
    /// Builds `ZOrderDrain` for a display group's raise circle.
    let drain:
        ([WindowID], ZOrderDrain.Policy) ->
            ZOrderDrain?
    /// Diagnostic logger.
    let log: (String) -> Void
    /// Teardown raise policy and overall time budget.
    let policy: ZOrderDrain.Policy

    /// Raises each display group's circle until groups or budget are
    /// exhausted.
    func run(_ circles: [(display: UInt32, order: [WindowID])]) {
        // `stop()` also runs mid-session on an AX REVOKE, and
        // that path must not reach the drain: every raise lands
        // nothing while the WindowServer read keeps answering
        // (CGWindowList needs no AX grant) — the drain is not
        // blind, merely never satisfied, and would spend the
        // whole budget sleeping for landings that cannot come
        // (#688, code review 2026-08-03).
        guard isTrusted() else {
            log(
                "gatherWindows: no Accessibility permission — "
                    + "skipping the raise circle"
            )
            return
        }
        let deadline = now() + policy.budget
        let dropped = unbeatable()
        for circle in circles {
            let remaining = deadline - now()
            guard remaining > 0 else {
                log(
                    "gatherWindows: raise budget exceeded — "
                        + "stacking left partial"
                )
                return
            }
            let order = circle.order.filter { $0 != dropped }
            guard !order.isEmpty,
                let drain = drain(order, policy.limited(to: remaining))
            else { continue }
            let raised = drain.run(order)
            // NOT `raised.count < order.count`: the drain raises
            // only what is out of place, so fewer than the circle
            // names is ordinary success. The clock is the signal
            // (this policy drops its tail, so `run` returns only
            // on a finished plan or a spent budget), and
            // `!raised.isEmpty` removes the already-correct
            // group's false positive (code review, 2026-08-03).
            guard !raised.isEmpty, now() >= deadline else { continue }
            log(
                "gatherWindows: raise budget spent on display "
                    + "\(circle.display) after \(raised.count) "
                    + "raise(s) — the rest of its circle was left "
                    + "in place"
            )
        }
    }
}
