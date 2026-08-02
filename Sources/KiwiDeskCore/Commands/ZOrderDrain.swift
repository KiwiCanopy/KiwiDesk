import Foundation

/// Runs a z-order raise sequence and verifies each raise LANDED
/// before issuing the next (#684).
///
/// `AXUIElementPerformAction(kAXRaiseAction)` returns once the
/// target app has accepted the action, not once it has performed
/// it. Measured on an overflowing scrolling row (Obsidian,
/// Telegram, Ghostty, Zen, ChatGPT, Notizen, Claude): the call
/// returns in 0.4-3.8 ms and the window reaches its new stacking
/// position 1-20 ms later. The whole sequence issues in ~10 ms, so
/// every raise is still in flight when the next goes out and the
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
/// waits never timed out at a 400 ms cap — so the second pass
/// below is a backstop, not the mechanism.
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

    /// How long one raise may be waited on before the drain gives
    /// up on it and moves to the next — 6x the 20 ms worst case
    /// measured. Per-window, so one wedged app cannot stall the
    /// windows behind it in the sequence.
    static let landingLimit: TimeInterval = 0.12
    /// Whole-sequence ceiling, ~5x the ~55 ms a verified 6-window
    /// row measured. It has to be a total, not a per-window sum:
    /// eight windows at the per-window limit would drain 1 s, and
    /// `zOrderRestoresInFlight` — which holds the mouse warp — is
    /// raised for exactly this long.
    static let totalLimit: TimeInterval = 0.4
    /// Poll interval while waiting for a raise to land. The read
    /// costs ~0.4 ms, so this spends under a tenth of a core.
    static let pollInterval: TimeInterval = 0.005
    /// One verifying pass, then one re-read and retry of whatever
    /// is still out of place.
    static let maxPasses = 2

    /// Raises `order` — deepest first, each landing on top of the
    /// last — and returns once the stacking matches or the budget
    /// is spent. Blocking: call it on `zOrderQueue`, never on the
    /// main actor.
    func run(_ order: [WindowID]) {
        let deadline = now() + Self.totalLimit
        for _ in 0..<Self.maxPasses {
            guard isCurrent() else { return }
            let targets = Set(order)
            let seen = stacking().filter { targets.contains($0) }
            let plan = Self.plan(raiseOrder: order, observed: seen)
            guard !plan.isEmpty else { return }
            let planned = Set(plan)
            // The windows the plan left alone keep their observed
            // order and belong below every raised one — that is
            // what makes them safe to leave alone, so they are
            // part of what each landing is checked against.
            let untouched = seen.filter { !planned.contains($0) }
            guard
                issue(
                    plan,
                    over: untouched,
                    deadline: deadline
                )
            else { return }
        }
    }

    /// Issues one pass. Returns false when the drain must stop
    /// outright — superseded, or out of budget with the remaining
    /// raises fired off unverified.
    private func issue(
        _ plan: [WindowID],
        over untouched: [WindowID],
        deadline: TimeInterval
    ) -> Bool {
        var raised: [WindowID] = []
        for (index, id) in plan.enumerated() {
            guard isCurrent() else { return false }
            raise(id)
            raised.append(id)
            guard now() < deadline else {
                // Out of budget. Issue the rest without waiting
                // rather than dropping them: unverified is the
                // behavior every pile had before this drain, while
                // a dropped raise is a window left definitely in
                // the wrong place.
                for rest in plan.dropFirst(index + 1) { raise(rest) }
                return false
            }
            _ = awaitLanding(
                raised: raised,
                over: untouched,
                deadline: deadline
            )
        }
        return true
    }

    /// Polls until the windows raised so far stand front-to-back
    /// in the reverse of the order they were raised in, above the
    /// ones this pass left alone. Relative, never "is it
    /// frontmost": the focused window sits above the whole pile by
    /// design (it is re-asserted last), and a window on another
    /// display is listed among these and can never be beaten.
    /// Returns false on timeout — the drain then moves on.
    private func awaitLanding(
        raised: [WindowID],
        over untouched: [WindowID],
        deadline: TimeInterval
    ) -> Bool {
        let want = Array(raised.reversed()) + untouched
        let members = Set(want)
        let limit = min(now() + Self.landingLimit, deadline)
        while true {
            if stacking().filter({ members.contains($0) }) == want {
                return true
            }
            guard now() < limit else { return false }
            sleep(Self.pollInterval)
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
    /// A target the WindowServer does not list on screen —
    /// minimized, or on another space — is dropped: it has no
    /// stacking to fix and no landing that could ever be
    /// verified. Pure math, unit-tested.
    static func plan(
        raiseOrder: [WindowID],
        observed: [WindowID]
    ) -> [WindowID] {
        let onScreen = Set(observed)
        // Desired front-to-back: the last raise lands on top.
        let desired = raiseOrder.reversed().filter {
            onScreen.contains($0)
        }
        var settled = 0
        while settled < desired.count {
            let tail = Array(desired.suffix(settled + 1))
            let members = Set(tail)
            guard observed.filter({ members.contains($0) }) == tail
            else { break }
            settled += 1
        }
        return Array(
            desired.prefix(desired.count - settled).reversed()
        )
    }
}

/// The z-order raise generation (#418/#425), in a lock rather
/// than on the main actor: the drain reads it between raises from
/// `zOrderQueue` to abandon a sequence a newer one has superseded
/// (#684), and every other reader is main-actor code that would
/// otherwise have to hop threads to answer it.
final class ZOrderGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0

    var value: Int { lock.withLock { current } }

    /// Starts a new sequence, returning its generation.
    func bump() -> Int {
        lock.withLock {
            current += 1
            return current
        }
    }
}
