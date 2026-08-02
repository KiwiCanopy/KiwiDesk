import Foundation

/// Runs a z-order raise sequence and verifies each raise LANDED
/// before issuing the next (#684).
///
/// `AXUIElementPerformAction(kAXRaiseAction)` returns once the
/// target app has accepted the action, not once it has performed
/// it. Measured on an overflowing scrolling row (Obsidian,
/// Telegram, Ghostty, Zen, ChatGPT, Notizen, Claude, on device
/// 2026-08-02, macOS 26.6): the call returns in 0.4-3.8 ms and
/// the window reaches its new stacking position 1-20 ms later.
/// The whole sequence issues in ~10 ms, so every raise is still
/// in flight when the next goes out and the
/// apps land them in whatever order they get to them — the pile
/// settled scrambled in 3 of 3 runs. The window raised FIRST
/// suffers most, because every later raise has to beat it.
///
/// So the order cannot rest on the return. The drain reads the
/// WindowServer's real stacking instead (one
/// `CGWindowListCopyWindowInfo`, ~0.4 ms) and only issues the next
/// raise once the last one is visibly above its predecessors. With
/// that wait the same row settled correctly, the whole sequence
/// costing ~55 ms. No raise was ever *lost* in measurement — the
/// waits never timed out at a 400 ms cap — which is why a window
/// that misses its landing is left to the next restore instead of
/// being retried here (`run` carries that argument).
///
/// It also raises only what is out of place (`plan`): stacking is
/// by distance from focus, so a short focus jump leaves most pairs
/// already correctly ordered, and a needless raise is not free —
/// it steals focus for an echo and drags a slow app back to the
/// front of the pile.
///
/// Every machine effect is a seam, so the loop is unit-testable
/// without a WindowServer or a running app.
struct ZOrderDrain: Sendable {
    /// Issues the bare AX raise (`AXHelper.raiseQuietly`).
    let raise: @Sendable (WindowID) -> Void
    /// The WindowServer's on-screen stacking, front to back.
    let stacking: @Sendable () -> [WindowID]
    /// Monotonic seconds.
    let now: @Sendable () -> TimeInterval
    /// Blocks the calling queue for that many seconds.
    let sleep: @Sendable (TimeInterval) -> Void
    /// False once a newer raise sequence has superseded this one,
    /// so a stale drain abandons the raises it has left instead of
    /// finishing them and fighting the newer sequence.
    let isCurrent: @Sendable () -> Bool
    /// Windows the sequence must land ABOVE but never raises — the
    /// tiled plane under a float raise (#418).
    ///
    /// Without it the diff below is blind to the only thing that
    /// raise is for: floats keep their order among themselves, so
    /// a float layer buried under the tile `focusWindow` just
    /// raised reads as "already correct" and nothing is re-raised.
    /// The pile restores pass none — their members are ordered
    /// against each other, and the focused window sits above them
    /// by design. Required at every call site rather than
    /// defaulted, so a new sequence has to decide.
    let floor: [WindowID]
    /// Whole-sequence ceiling. A total, not a per-window sum:
    /// eight windows at `landingLimit` would drain a second.
    ///
    /// Required at every call site rather than defaulted, for the
    /// same reason as `floor` — and here the sequences genuinely
    /// disagree. A live restore is bounded by
    /// `zOrderRestoresInFlight`, which holds the mouse warp for
    /// exactly as long as the drain runs (`restoreBudget`). The
    /// teardown restack is bounded by the quit path's own wall
    /// clock instead, and weighs the trade the other way: nothing
    /// runs after it to heal a miss, so it buys more verification
    /// than a restore would — but a quit that hangs is worse than
    /// a quit that stacks imperfectly, so it is still a ceiling
    /// (#688, `KiwiCore+TeardownRaise`).
    let budget: TimeInterval
    /// What a spent budget does to the raises the plan has left:
    /// issue them unverified (true) or drop them (false).
    ///
    /// A live restore issues them. Its caller stamped every target
    /// in the raise echo ledger, so a dropped raise is both a
    /// window left definitely in the wrong place AND a stamp
    /// nothing consumes; and the cost of issuing is paid on
    /// `zOrderQueue`, not anywhere a user is waiting.
    ///
    /// The teardown restack drops them, because for it `budget` is
    /// a WALL CLOCK and issuing is not free: each raise is a
    /// blocking `AXUIElementPerformAction` bounded only by the
    /// 0.25 s AX messaging timeout, on the main actor, after the
    /// budget is already spent. A nine-window tail could add
    /// seconds to a quit that had promised to stop at one — and
    /// the quit path has no echo ledger to corrupt, so the reason
    /// the restores issue does not apply to it (code review,
    /// 2026-08-03). A quit that hangs is worse than a quit that
    /// stacks imperfectly.
    let spendsBudgetOnUnverifiedTail: Bool

    /// How long one raise may be waited on before the drain gives
    /// up on it and moves to the next — 6x the 20 ms worst case
    /// measured. Per-window, so one wedged app cannot stall the
    /// windows behind it in the sequence.
    static let landingLimit: TimeInterval = 0.12
    /// A live restore's `budget`, ~5x the ~55 ms a verified
    /// 6-window row measured.
    static let restoreBudget: TimeInterval = 0.4
    /// The teardown restack's `budget` — the same 1 s the bare
    /// loop it replaced was capped at, spent across every display
    /// group rather than per group (#688).
    ///
    /// It sits here beside `restoreBudget` rather than on its
    /// caller so a third sequence has one precedent for where a
    /// budget lives, not two contradicting ones (architect review,
    /// 2026-08-03).
    ///
    /// More than a restore's, for the reason `budget` states:
    /// nothing runs after the teardown restack to heal a miss, so
    /// waiting is worth more there than anywhere else. Still a
    /// ceiling, because a quit that hangs is worse than a quit
    /// that stacks imperfectly — and a real one only because that
    /// path also drops its tail rather than issuing it
    /// (`spendsBudgetOnUnverifiedTail`).
    static let teardownBudget: TimeInterval = 1.0
    /// Poll interval while waiting for a raise to land. The read
    /// costs ~0.4 ms, so this spends under a tenth of a core.
    static let pollInterval: TimeInterval = 0.005
    /// Raises `order` — deepest first, each landing on top of the
    /// last — and returns once every raise has been issued or the
    /// budget is spent. Blocking: call it on `zOrderQueue`, never
    /// on the main actor — with one exception, the teardown
    /// restack, which runs on the main actor because by then
    /// there is no live session left to block. The whole quit
    /// gather is already synchronous AX IPC there, and its budget
    /// is the thing bounding it (#688).
    ///
    /// **Exactly one pass, and never the same window twice.** A
    /// retry pass for the windows that missed their landing was
    /// built and removed on device evidence: the raise echo ledger
    /// (`zOrderRaiseEchoes`) consumes a window's stamp on its
    /// FIRST echo, so a second raise of that window inside one
    /// sequence emits an echo nothing reverts, and it reads as a
    /// deliberate focus change — focus lands on the pile-mate and
    /// a scrolling row pans to it. The last window raised is the
    /// one next to the focus, so the visible symptom is the focus
    /// sliding one slot after every restore (owner QA,
    /// 2026-08-02). Re-stamping per pass would be the fix if a
    /// retry ever earns its place; measurement says it has not —
    /// no raise was ever LOST, only late, and a late one is put
    /// right by the next restore.
    ///
    /// Returns the windows it actually raised, which is not the
    /// whole order: the caller stamped every target in the raise
    /// echo ledger, and a window that is never raised emits no
    /// echo to consume its stamp — so the caller drops the rest
    /// (`releaseZOrderStamps`).
    func run(_ rawOrder: [WindowID]) -> [WindowID] {
        guard isCurrent() else { return [] }
        let deadline = now() + budget
        // Uniqued, because "never twice" must be a property of
        // this loop rather than a hope about its input: a repeated
        // id makes every tail check fail (a filtered observation
        // can never reproduce a duplicate), so `plan` would return
        // it twice and raise it twice — the focus slide above, via
        // a caller's bug instead of ours. No caller can produce
        // one today (code review, 2026-08-02).
        var seenIDs = Set<WindowID>()
        let order = rawOrder.filter { seenIDs.insert($0).inserted }
        let targets = seenIDs
        let observed = stacking()
        // An empty read is `CGWindowListCopyWindowInfo` answering
        // with nothing at all — a nil return, since the list
        // otherwise always carries the menu bar. It is never a
        // screen with no windows: we are here to raise windows
        // that exist. Diffing against it would drop every
        // raise silently and permanently for as long as the read
        // failed, which is the opposite of what the budget branch
        // below argues: unverified is what every pile did before
        // this drain, a dropped raise is a window left definitely
        // in the wrong place (architect review, 2026-08-02).
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
        // The windows the plan left alone keep their observed
        // order and belong below every raised one — that is
        // what makes them safe to leave alone, so they are
        // part of what each landing is checked against.
        let untouched = seen.filter { !planned.contains($0) }
        return issue(plan, over: untouched, deadline: deadline)
    }

    /// Issues the plan, waiting for each raise to land before the
    /// next. Every window here is raised exactly once — see `run`
    /// — and every one of them comes back in the return value,
    /// including the unverified tail: the caller keys the echo
    /// ledger off this, and a raise left out of it would have its
    /// stamp dropped while its echo was still in flight, which is
    /// the focus jump all over again.
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
                guard spendsBudgetOnUnverifiedTail else {
                    return raised
                }
                // Out of budget. Issue the rest without waiting
                // rather than dropping them: unverified is the
                // behavior every pile had before this drain, while
                // a dropped raise is a window left definitely in
                // the wrong place.
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

    /// Polls until the windows raised so far stand front-to-back
    /// in the reverse of the order they were raised in, above the
    /// ones this pass left alone and clear of the floor. Relative,
    /// never "is it frontmost": the focused window sits above the
    /// whole pile by design (it is re-asserted last), and a window
    /// on another display is listed among these and can never be
    /// beaten. Returns false on timeout — the drain then moves on.
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

    /// Whether every one of `raised` stands in front of the whole
    /// floor. Vacuously true with no floor, which is every pile
    /// restore.
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

    /// The windows of `raiseOrder` that are actually out of place,
    /// in raise order — the minimal set, because a raise always
    /// goes to the front: raising a set S in order leaves S at the
    /// front in reverse-raise order and everything else in the
    /// order it already had. So the work is exactly the front
    /// stretch of the desired order whose tail does not already
    /// stand correctly, and the tail check only gets stricter as
    /// it grows, which is why the scan can stop at the first miss.
    ///
    /// A window standing correctly among the targets but still
    /// under the `floor` is out of place too — that is the whole
    /// job of a float raise, and the only reason the floor is a
    /// parameter here.
    ///
    /// A target the WindowServer does not list on screen —
    /// minimized, or on another space — is dropped: it has no
    /// stacking to fix and no landing that could ever be
    /// verified. `observed` is the full front-to-back list, not
    /// just the targets, because the floor's position is in it.
    /// Pure math, unit-tested.
    static func plan(
        raiseOrder: [WindowID],
        observed: [WindowID],
        above floor: [WindowID]
    ) -> [WindowID] {
        let onScreen = Set(observed)
        // Desired front-to-back: the last raise lands on top.
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
