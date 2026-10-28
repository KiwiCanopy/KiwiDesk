import Foundation

/// The removal pause under a locked session (#2538). Neither the
/// AX list nor the on-screen census is evidence while the session
/// rests (#1285): a display waking behind the lock drops every
/// window from the census for a moment, and a sweep then closed
/// the whole desk. So a sweep removes nothing while locked; the
/// apps it refused are reconciled once the lock is gone.
struct LockedRemovals {
    /// Whether the session's screen is locked now. Wired in
    /// `KiwiCore+Bootstrap`; the false default keeps every harness
    /// inert.
    var isLocked: () -> Bool = { false }
    /// Apps a lock refused a removal, owed a reconcile on return.
    var refused: Set<pid_t> = []
}

extension EventLoop {
    /// True when the session is locked: the sweep keeps every
    /// candidate of `pid` and the app is owed a reconcile. Logs
    /// once per app per lock.
    func refusesLockedRemovals(pid: pid_t, app: AppRef) -> Bool {
        guard lockedRemovals.isLocked() else { return false }
        if lockedRemovals.refused.insert(pid).inserted {
            onLog(
                "close distrust: \(app.bundleID ?? app.name) missing "
                    + "from the AX list while the session is "
                    + "locked — removals refused (#2538)"
            )
        }
        return true
    }

    /// Reconciles every app a lock refused, once the lock is gone.
    /// Called on the return leg and on every heal tick, since the
    /// unlock can be announced while the flag still reads locked.
    func reconcileLockRefused() {
        guard !lockedRemovals.refused.isEmpty,
            !lockedRemovals.isLocked()
        else { return }
        let pids = lockedRemovals.refused
        lockedRemovals.refused = []
        for pid in pids.sorted() where observers[pid] != nil {
            reconcileOffMain(pid: pid, app: appRef(of: pid))
        }
    }
}
