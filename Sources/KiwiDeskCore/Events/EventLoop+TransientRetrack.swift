import ApplicationServices

/// The one-shot re-track ledger (#675): a window a transient
/// filter in `track` dropped is asked once more. Split from
/// `EventLoop+Tracking.swift` for file size (§2).
extension EventLoop {
    /// Ids beyond this stop scheduling re-tracks for their app
    /// until it detaches — an overlay-minting app then degrades
    /// to the sweep and incidental reconciles instead of growing
    /// the ledger for the session (#675 review).
    static let transientRetryCap = 64

    /// Queues one delayed re-track for a window a transient
    /// filter dropped (#675). Mid-launch (a Dock-stack zoom, a
    /// fade-in) a window can read unbacked or alpha-0 once, and
    /// both filters return with no retry — the only healing pass
    /// was whatever reconcile happened to come, which for a
    /// fresh launch may be none. One retry per window id, so a
    /// permanent invisible helper (#309) re-drops once on the
    /// retry and then stays quiet; the ledger clears with its
    /// app (`detach`) and is capped per app. The wire fires only
    /// when the queue was empty: later drops ride the already
    /// armed one-shot instead of pushing its deadline back with
    /// every reschedule.
    func markTransientDrop(pid: pid_t, id: WindowID) {
        guard
            transientRetried[pid, default: []].count
                < Self.transientRetryCap,
            transientRetried[pid, default: []]
                .insert(id).inserted
        else { return }
        queueRetrack(pid: pid)
    }

    /// Queues `pid` for the scheduled re-track — the transient
    /// ledger's one arm, and a shadow candidate's, which re-asks
    /// until its host lists outside that ledger (#1785).
    func queueRetrack(pid: pid_t) {
        let wasIdle = pendingRetrack.isEmpty
        pendingRetrack.insert(pid)
        if wasIdle {
            onTransientDrop()
        }
    }

    /// Hands the pids owed a re-track to the scheduled task and
    /// clears the queue (#675).
    func drainPendingRetrack() -> Set<pid_t> {
        let pids = pendingRetrack
        pendingRetrack = []
        return pids
    }
}
