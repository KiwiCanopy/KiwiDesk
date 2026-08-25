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
    enum Key: Hashable, CaseIterable {
        /// Deferred switch to a hidden window's Space
        /// (`scheduleFocusFollow`).
        case focusFollow
        /// One-shot startup sweep re-tracking windows the cold
        /// AX scan missed (`scheduleStartupSweep`) — and, once it
        /// has fired, each of its own chunks (#801): the pass is
        /// one job, so re-using its slot is what makes
        /// `cancelAll()` stop a sweep mid-flight.
        case startupSweep
        /// The next chunk of the startup scan (`driveBootScan`,
        /// #801). The scan hands the run loop back between
        /// chunks; this is what brings it back.
        case bootScan
        /// The next app whose boot work a per-app budget cut
        /// short (`drainDeferredBootApps`, #803) — one per turn,
        /// so completing them cannot re-block the run loop.
        case deferredBootApps
        /// One-shot layout re-assert after a virtual-space
        /// switch (`scheduleSpaceSettle`).
        case spaceSettle
        /// One-shot focus re-assert after a no-follow
        /// `move_to_space` (`scheduleMoveSettle`, #482/#483).
        case moveSettle
        /// Layout + focus re-assert after a native desktop
        /// switch (`settleAfterDesktopSwitch`).
        case desktopSettle
        /// Reaps the window a no-follow `move_to_desktop` sent
        /// to another Desktop (`scheduleDesktopMoveReap`): no OS
        /// switch follows such a move, so nothing else is
        /// guaranteed to notice the window left.
        case desktopMoveReap
        /// Re-asserts every desired focus ring's VISIBILITY and
        /// stacking after a drag/drop or animated transition
        /// (`scheduleBorderDropReconcile`) — early on purpose, and
        /// geometry-free while a window animates.
        case borderDropSettle
        /// Re-syncs ring AND mark GEOMETRY from real window state
        /// a grace after the last animation ends
        /// (`scheduleBorderResync`, #596). A separate slot from
        /// `borderDropSettle` deliberately: they run at different
        /// delays for different reasons, so sharing one would let
        /// whichever landed second cancel the other — silently
        /// dropping either the un-hide or the sticky mark's heal.
        case borderResync
        /// Coalesced re-raise of the float layer after focus lands
        /// on a tiled window (`raiseFloatsAbove`) — a burst of focus
        /// changes collapses to one raise for the final target.
        case floatRaise
        /// Self-rearming adoption-heal sweep re-adopting windows
        /// every event path missed (`scheduleAdoptionHeal`,
        /// #675).
        case adoptionHeal
        /// One-shot re-track of windows the transient filters
        /// dropped mid-launch (`scheduleTransientRetrack`,
        /// #675).
        case transientRetrack
        /// Re-render of the bars after a drawn window title
        /// changed (`handleTitleChangedForBars`). The one slot
        /// here whose reschedule is the POINT rather than a
        /// correctness guard: a title event arrives as fast as a
        /// keystroke, and cancel-and-replace is what turns a
        /// burst into one refresh when it stops.
        case barTitleRefresh
    }

    private var tasks: [Key: Task<Void, Never>] = [:]
    private var burstStarts: [Key: ContinuousClock.Instant] = [:]

    /// Runs `body` after `delay` unless the key is rescheduled
    /// or cancelled first. Cancellation is checked once, after
    /// the sleep: `body` is synchronous main-actor code, so a
    /// cancel cannot interleave with it once it has started.
    /// `body` is retained until it fires or is cancelled, so
    /// capture the core weakly (see the type doc) — a strong
    /// capture would pin it for the pending delay.
    ///
    /// When `maxWait` is provided, continuous reschedules within
    /// a burst will not delay execution past `maxWait` from the
    /// burst's initial schedule (#900).
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

    /// Whether `key` has work pending — the seam a test reads to
    /// prove a path ARMED its deferred work, without waiting the
    /// delay out or letting the body reach the machine.
    func isScheduled(_ key: Key) -> Bool { tasks[key] != nil }

    func cancel(_ key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
        burstStarts[key] = nil
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
        burstStarts.removeAll()
    }
}
