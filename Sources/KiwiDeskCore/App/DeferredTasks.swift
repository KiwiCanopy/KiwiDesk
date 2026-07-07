import Foundation

/// Owns KiwiCore's deferred one-shot settle tasks, keyed so a
/// reschedule self-cancels the prior run and teardown can cancel
/// everything at once instead of hand-listing fields (#49) — the
/// hand-kept cancel list is how a missing cancel slipped through
/// review once already (#48).
///
/// Only the store/cancel/sleep protocol lives here; the settle
/// bodies stay closures at the call sites because their delays,
/// guard predicates, and post-work genuinely differ (AGENTS.md
/// §2.4). Bodies run on the main actor and should capture the
/// core weakly, as the call sites do.
@MainActor
final class DeferredTasks {
    /// One slot per deferred job; scheduling a key replaces
    /// (cancels) whatever that key was still waiting on.
    enum Key: Hashable {
        /// Deferred switch to a hidden window's virtual space
        /// (`scheduleFocusFollow`).
        case focusFollow
        /// One-shot startup sweep re-tracking windows the cold
        /// AX scan missed (`scheduleStartupSweep`).
        case startupSweep
        /// One-shot layout re-assert after a virtual-space
        /// switch (`scheduleSpaceSettle`).
        case spaceSettle
        /// Layout + focus re-assert after a native desktop
        /// switch (`settleAfterNativeSwitch`).
        case nativeSpaceSettle
    }

    private var tasks: [Key: Task<Void, Never>] = [:]

    /// Runs `body` after `delay` unless the key is rescheduled
    /// or cancelled first. Cancellation is checked once, after
    /// the sleep: `body` is synchronous main-actor code, so a
    /// cancel cannot interleave with it once it has started.
    /// `body` is retained until it fires or is cancelled, so
    /// capture the core weakly (see the type doc) — a strong
    /// capture would pin it for the pending delay.
    func schedule(
        _ key: Key,
        after delay: Duration,
        _ body: @escaping @MainActor () -> Void
    ) {
        tasks[key]?.cancel()
        tasks[key] = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            body()
        }
    }

    func cancel(_ key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    /// The task currently stored for a key — lets tests pin the
    /// cancel-and-replace claims (identity + `isCancelled`).
    /// Not a pending-check: a fired body leaves its *finished*
    /// task in the slot (bounded — one per key — and inert), so
    /// this stays non-nil after firing; only `cancel`/`cancelAll`
    /// clear the slot.
    func task(for key: Key) -> Task<Void, Never>? {
        tasks[key]
    }

    /// Cancels every pending task — the one call teardown makes,
    /// so `stop()` cannot forget a newly added key.
    func cancelAll() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
    }
}
