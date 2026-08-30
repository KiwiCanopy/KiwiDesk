import Foundation

/// Runs a z-order raise sequence and verifies each raise landed before issuing
/// the next (#684).
struct ZOrderDrain: Sendable {
    /// Issues the bare AX raise (`AXHelper.raiseQuietly`).
    let raise: @Sendable (WindowID) -> Void
    /// The WindowServer's on-screen stacking, front to back.
    let stacking: @Sendable () -> [WindowID]
    /// Monotonic seconds.
    let now: @Sendable () -> TimeInterval
    /// Blocks the calling queue for that many seconds.
    let sleep: @Sendable (TimeInterval) -> Void
    /// False once a newer raise sequence has superseded this one.
    let isCurrent: @Sendable () -> Bool
    /// Windows the sequence must land above but never raises (#418).
    let floor: [WindowID]
    /// Budget and exhaustion policy.
    let policy: Policy

    /// Max per-window landing wait (120ms).
    static let landingLimit: TimeInterval = 0.12
    /// Poll interval while awaiting landing (5ms).
    static let pollInterval: TimeInterval = 0.005

    /// Raises `order` deepest first; exactly one pass per window (owner QA,
    /// 2026-08-02; architect review, 2026-08-02; #688, #689).
    func run(_ rawOrder: [WindowID]) -> [WindowID] {
        guard isCurrent() else { return [] }
        let deadline = now() + policy.budget
        // Uniqued to prevent duplicate raises on caller error
        // (review 2026-08-02).
        var seenIDs = Set<WindowID>()
        let order = rawOrder.filter { seenIDs.insert($0).inserted }
        let targets = seenIDs
        let observed = stacking()
        guard !observed.isEmpty else {
            order.forEach(raise)
            return order
        }
        let seen = observed.filter { targets.contains($0) }
        let plan = Self.plan(
            raiseOrder: order,
            observed: observed,
            above: floor
        )
        guard !plan.isEmpty else { return [] }
        let planned = Set(plan)
        let untouched = seen.filter { !planned.contains($0) }
        return issue(plan, over: untouched, deadline: deadline)
    }

    /// Issues the planned raises, awaiting verification per step.
    private func issue(
        _ plan: [WindowID],
        over untouched: [WindowID],
        deadline: TimeInterval
    ) -> [WindowID] {
        var raised: [WindowID] = []
        for (index, id) in plan.enumerated() {
            guard isCurrent() else { return raised }
            raise(id)
            raised.append(id)
            guard now() < deadline else {
                guard policy.spendsBudgetOnUnverifiedTail else {
                    return raised
                }
                // Out of budget: issue remaining unverified.
                let rest = plan.dropFirst(index + 1)
                rest.forEach(raise)
                return raised + rest
            }
            _ = awaitLanding(
                raised: raised,
                over: untouched,
                deadline: deadline
            )
        }
        return raised
    }

    /// Polls until raised windows stand in desired relative order above floor.
    private func awaitLanding(
        raised: [WindowID],
        over untouched: [WindowID],
        deadline: TimeInterval
    ) -> Bool {
        let want = Array(raised.reversed()) + untouched
        let members = Set(want)
        let below = Set(floor)
        let limit = min(now() + Self.landingLimit, deadline)
        while true {
            let observed = stacking()
            if observed.filter({ members.contains($0) }) == want,
                Self.clears(raised, floor: below, in: observed)
            {
                return true
            }
            guard now() < limit else { return false }
            sleep(Self.pollInterval)
        }
    }

    /// Whether every raised window stands in front of the floor set.
    private static func clears(
        _ raised: [WindowID],
        floor: Set<WindowID>,
        in observed: [WindowID]
    ) -> Bool {
        guard
            let ceiling = observed.firstIndex(where: {
                floor.contains($0)
            })
        else { return true }
        return raised.allSatisfy { id in
            guard let at = observed.firstIndex(of: id) else {
                return false
            }
            return at < ceiling
        }
    }

    /// Computes minimal out-of-order window prefix to raise (#418).
    static func plan(
        raiseOrder: [WindowID],
        observed: [WindowID],
        above floor: [WindowID]
    ) -> [WindowID] {
        let onScreen = Set(observed)
        let desired = raiseOrder.reversed().filter {
            onScreen.contains($0)
        }
        let below = Set(floor)
        var settled = 0
        while settled < desired.count {
            let tail = Array(desired.suffix(settled + 1))
            let members = Set(tail)
            guard observed.filter({ members.contains($0) }) == tail,
                clears(tail, floor: below, in: observed)
            else { break }
            settled += 1
        }
        return Array(
            desired.prefix(desired.count - settled).reversed()
        )
    }
}
