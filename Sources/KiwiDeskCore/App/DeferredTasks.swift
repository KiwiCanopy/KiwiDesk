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
        case desktopFollowReap
        /// Verifies desktop switch dispatch (#1023).
        case desktopSwitchVerify
        case borderDropSettle
        /// Re-syncs border and mark geometry after animations (#596).
        case borderResync
        case floatRaise
        /// Adoption-heal sweep for unhandled windows (#675).
        case adoptionHeal
        /// Re-tracks windows dropped mid-launch (#675).
        case transientRetrack
        case barTitleRefresh
    }

    private var tasks: [Key: Task<Void, Never>] = [:]
    private var burstStarts: [Key: ContinuousClock.Instant] = [:]

    /// Schedules `body` after `delay` (bounded by `maxWait` across bursts,
    /// #900).
    func schedule(
        _ key: Key,
        after delay: Duration,
        maxWait: Duration? = nil,
        _ body: @escaping @MainActor () -> Void
    ) {
        tasks[key]?.cancel()
        tasks[key] = nil

        let start = burstStarts[key] ?? ContinuousClock.now
        if let maxWait, ContinuousClock.now - start >= maxWait {
            burstStarts[key] = nil
            body()
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

        tasks[key] = Task { @MainActor in
            try? await Task.sleep(for: sleepDuration)
            guard !Task.isCancelled else { return }
            burstStarts[key] = nil
            body()
        }
    }

    /// True if `key` has work scheduled.
    func isScheduled(_ key: Key) -> Bool { tasks[key] != nil }

    func cancel(_ key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
        burstStarts[key] = nil
    }

    /// Returns task stored for key (used for test assertions).
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
