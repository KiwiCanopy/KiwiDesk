import Foundation

/// Owns KiwiCore's deferred one-shot settle tasks with self-cancelling keys
/// (#48, #49).
@MainActor
final class DeferredTasks {
    /// Distinct slots for deferred jobs (cancel-and-replace per slot).
    enum Key: Hashable, CaseIterable {
        case focusFollow
        /// One-shot startup sweep re-tracking windows
        /// (`scheduleStartupSweep`, #801).
        case startupSweep
        /// Chunked startup scan (`driveBootScan`, #801).
        case bootScan
        /// Deferred app boot processing (`drainDeferredBootApps`, #803).
        case deferredBootApps
        case spaceSettle
        /// Focus re-assert after no-follow `move_to_space` (#482, #483).
        case moveSettle
        case desktopSettle
        case desktopMoveReap
        /// Adopts window sent to hidden desktop by follow (#1023).
        /// A separate slot from `desktopMoveReap` deliberately:
        /// keys are cancel-and-replace and the two verbs are one
        /// keystroke apart — whichever fired second would silently
        /// drop the other's reap.
        case desktopFollowReap
        /// Verifies desktop switch dispatch (#1023).
        case desktopSwitchVerify
        case borderDropSettle
        /// Re-syncs border and mark geometry after animations
        /// (#596). A separate slot from `borderDropSettle`
        /// deliberately: different delays for different reasons,
        /// and sharing one would let whichever landed second
        /// cancel the other.
        case borderResync
        case floatRaise
        /// Adoption-heal sweep for unhandled windows (#675).
        case adoptionHeal
        /// The heal's census read off the main actor (#1956);
        /// tracked so teardown cancels it before it re-arms.
        case adoptionHealRead
        /// A WindowServer create's wake sweep and its census read
        /// (#1877).
        case adoptionHealWake
        /// Re-tracks windows dropped mid-launch (#675).
        case transientRetrack
        /// Re-reads an app whose sweep removal was distrusted
        /// (#1157). A separate slot from `transientRetrack`
        /// deliberately: a refusal riding a drop's part-spent
        /// deadline could fire early and strand a true close.
        case removalRecheck
        /// Bar re-render on a drawn title change — the one slot
        /// whose reschedule is the POINT: cancel-and-replace turns
        /// a keystroke-rate burst into one refresh when it stops.
        case barTitleRefresh
        /// Re-centres a Space chip whose strip hold ended (#1528
        /// item 21), after the render or relayout that ended it
        /// unwinds — never a bar refresh nested inside one.
        case stripRecentre
        /// Re-reads the away ledger against one per-Desktop
        /// census while it is non-empty (#1146).
        case awayCensus
        /// Adopts the window an Open-or-Focus reach switched to
        /// (#1146). Its own slot for `desktopFollowReap`'s reason:
        /// a follow and a reach are one keystroke apart, and
        /// cancel-and-replace would drop whichever fired first.
        case awayReachReap
        /// Re-publishes the displays after the menu-bar
        /// auto-hide pref flips (#1386).
        case menuBarRemeasure
        /// The profile choice a screen-count change waits on
        /// until the reports stop (#1612).
        case monitorSettle
        /// The cross-session match's title pass and its close
        /// (#1385, `KiwiCore+CrossSession`).
        case crossSessionSettle
        case crossSessionClose

        /// Whether a body in this slot runs as its scheduler's
        /// motion, late (#804 ▸ Ruling 2), or always as ambient
        /// motion: a slot coalescing many callers, or one the
        /// system alone schedules, belongs to no one press.
        var carriesCause: Bool {
            switch self {
            case .focusFollow, .spaceSettle, .moveSettle,
                .desktopSettle, .desktopMoveReap, .desktopFollowReap,
                .desktopSwitchVerify, .borderDropSettle, .floatRaise,
                .awayReachReap:
                return true
            case .startupSweep, .bootScan, .deferredBootApps,
                .borderResync, .adoptionHeal, .adoptionHealRead,
                .adoptionHealWake,
                .transientRetrack, .removalRecheck, .barTitleRefresh,
                .awayCensus, .menuBarRemeasure, .stripRecentre,
                .monitorSettle, .crossSessionSettle, .crossSessionClose:
                return false
            }
        }
    }
    /// The motion cause in scope when a task is scheduled, and the
    /// door that runs a body under one (#804); `KiwiCore` wires
    /// both at bootstrap. Unwired, every body runs as it always did.
    var captureCause: @MainActor () -> MotionCause = { .ambient }
    var runUnder: @MainActor (MotionCause, () -> Void) -> Void = { $1() }

    /// The wait before a body runs, on the monotonic clock; a test
    /// steps it to fire a long slot at once (#1385).
    var sleep: @Sendable (Duration) async -> Void = {
        try? await Task.sleep(for: $0)
    }

    private var tasks: [Key: Task<Void, Never>] = [:]
    private var burstStarts: [Key: ContinuousClock.Instant] = [:]

    /// Schedules `body` after `delay` (bounded by `maxWait` across
    /// bursts, #900). Cancellation is checked once, after the
    /// sleep — `body` is synchronous main-actor code, so a cancel
    /// cannot interleave once it starts. `body` is retained until
    /// it fires: capture the core weakly.
    func schedule(
        _ key: Key,
        after delay: Duration,
        maxWait: Duration? = nil,
        _ body: @escaping @MainActor () -> Void
    ) {
        tasks[key]?.cancel()
        tasks[key] = nil

        let cause = key.carriesCause ? captureCause().asTail : .ambient
        let run = runUnder
        let start = burstStarts[key] ?? ContinuousClock.now
        if let maxWait, ContinuousClock.now - start >= maxWait {
            burstStarts[key] = nil
            // Still inside the caller's own call: its cause stands,
            // unless the slot belongs to no one press.
            key.carriesCause ? body() : run(.ambient, body)
            return
        }

        burstStarts[key] = start

        let sleepDuration: Duration
        if let maxWait {
            let elapsed = ContinuousClock.now - start
            let remaining = maxWait - elapsed
            sleepDuration = min(delay, max(.zero, remaining))
        } else {
            sleepDuration = delay
        }

        let sleep = sleep
        tasks[key] = Task { @MainActor in
            await sleep(sleepDuration)
            guard !Task.isCancelled else { return }
            burstStarts[key] = nil
            run(cause, body)
        }
    }

    /// Holds a task started elsewhere under `key`, cancelling the
    /// one it replaces.
    func track(_ key: Key, _ task: Task<Void, Never>) {
        tasks[key]?.cancel()
        tasks[key] = task
    }

    /// True if `key` has work scheduled.
    func isScheduled(_ key: Key) -> Bool { tasks[key] != nil }

    func cancel(_ key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
        burstStarts[key] = nil
    }

    /// The task stored for a key — for pinning cancel-and-replace
    /// claims. NOT a pending-check: a fired body leaves its
    /// finished task in the slot, so this stays non-nil after
    /// firing; only `cancel`/`cancelAll` clear it.
    func task(for key: Key) -> Task<Void, Never>? {
        tasks[key]
    }

    /// Cancels all pending tasks on teardown.
    func cancelAll() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        burstStarts.removeAll()
    }
}
