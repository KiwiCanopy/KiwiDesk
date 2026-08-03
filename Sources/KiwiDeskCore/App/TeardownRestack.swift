import Foundation

/// The quit-grid raise circle's control flow, with every machine
/// effect an injected seam — the same shape `ZOrderDrain` uses, and
/// for the same reason (#688).
///
/// It exists because the decisions here are the ones a quit gets
/// exactly one shot at, and they were guarded only by a source-text
/// scan: seven `#expect(source.contains(…))` needles re-typing the
/// body, which red on renaming a local and pass on `budget * 2`
/// (architect review, 2026-08-03). Behind these seams they are
/// ordinary unit tests instead. The wiring scan stays, narrowed to
/// what it is actually good at — proving the real seams are the
/// ones bound in production.
///
/// What it owns, in order: refuse to run at all without the
/// Accessibility grant; drop the one window no quiet raise can beat;
/// give each display group only what is LEFT of the whole-quit wall
/// clock; and stop dead once that clock is spent rather than
/// spending more of it issuing raises it can no longer verify.
/// Main-actor bound, deliberately unlike `ZOrderDrain`: that one
/// crosses to `zOrderQueue` and so is `Sendable` with `@Sendable`
/// seams, while this runs entirely inside the quit path on the
/// actor that calls it. Marking it `Sendable` would only force its
/// seams to give up their access to `KiwiCore`.
@MainActor
struct TeardownRestack {
    /// Whether the process still holds the Accessibility grant.
    let isTrusted: () -> Bool
    /// The frontmost app's key window, if any — the one member a
    /// quiet raise cannot lift anything above, so the one the
    /// circle drops rather than orders around.
    let unbeatable: () -> WindowID?
    /// Monotonic seconds.
    let now: () -> TimeInterval
    /// Builds the drain for one display group's circle. Returns nil
    /// when none of the group's windows can be reached (no AX
    /// element), which is not the same as an empty circle.
    let drain:
        ([WindowID], ZOrderDrain.Policy) ->
            ZOrderDrain?
    /// Diagnostics.
    let log: (String) -> Void
    /// The whole-quit policy. One value, so the deadline below and
    /// every group's drain cannot be sized from different things.
    let policy: ZOrderDrain.Policy

    /// Raises each group's circle in turn, verified, until the
    /// groups run out or the wall clock does.
    ///
    /// `circles` is one raise order per display group, already in
    /// `QuitGridLayout.raiseOrder` order and already filtered to
    /// windows the gather actually placed.
    func run(_ circles: [(display: UInt32, order: [WindowID])]) {
        // `stop()` also runs mid-session when the AX permission is
        // REVOKED (`KiwiCore+Lifecycle`), and that path must not
        // reach the drain. Every raise there lands nothing, while
        // the WindowServer read keeps answering — it reads
        // `CGWindowList`, which needs no AX grant — so the drain is
        // not blind, it is merely never satisfied: it would plan
        // the whole circle and spend the entire budget sleeping for
        // landings that cannot come. The loop this replaced cost
        // nothing there, so the gate is not an optimization, it is
        // that regression's fix (code review, 2026-08-03).
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
                // These groups are not raised at all, so their
                // piles keep whatever stacking the moves left them.
                //
                // The same answer the drain gives its own tail
                // (`policy.spendsBudgetOnUnverifiedTail` is false
                // for teardown), and for the same reason rather
                // than by accident: once the wall clock is spent,
                // issuing anything costs a blocking AX call per
                // window that the budget has no room left to pay
                // for. Dropping is what the bare loop this replaced
                // did at exactly this boundary.
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
            // A different fact from the one above, so it gets a
            // different line: this display's circle was started and
            // stopped part way, so the windows it never reached
            // keep whatever stacking the moves left them.
            //
            // NOT `raised.count < order.count`: the drain raises
            // only what is out of place, so raising fewer than the
            // circle names is its ordinary success. The signal is
            // the clock, which is exact here precisely because this
            // policy drops its tail — the only way `run` returns is
            // a finished plan or a spent budget. `!raised.isEmpty`
            // removes the one false positive that leaves: an
            // already-correct group returns after a single ~0.4 ms
            // read having raised nothing (code review,
            // 2026-08-03). It still over-reports a drain that
            // finished its whole plan right at the deadline, and
            // that window is `landingLimit` wide rather than one
            // poll interval, because `awaitLanding` caps its own
            // wait at the deadline.
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
