import ApplicationServices

/// The removal-distrust gate (#1157): a sweep close candidate
/// the on-screen census still shows is refused, because the
/// census may REFUSE a removal, never cause one. The argument —
/// the #913 mirror, the asymmetry, the accepted residue — is
/// accessibility.md's.
extension EventLoop {
    /// Follow-up reconciles one episode may queue. 2: the first
    /// queue can ride an already-armed one-shot's residual
    /// deadline, so one re-queue guarantees the episode a
    /// full-delay pass; past it the episode goes quiet rather
    /// than polling a permanently mismatched app (#1157).
    static let removalRecheckCap = 2

    /// Refuses one sweep removal for a window the census still
    /// shows. The first refusal of a continuous-absence episode
    /// logs; each refusal queues a follow-up reconcile up to
    /// `removalRecheckCap`, so a TRUE close still compositing
    /// at sweep time converges on the recheck one-shot instead
    /// of waiting for the next incidental pass.
    func refuseRemoval(_ id: WindowID, pid: pid_t, app: AppRef) {
        let spent = removalDistrusted[id] ?? 0
        if spent == 0 {
            onLog(
                "close distrust: w\(id.raw) of "
                    + "\(app.bundleID ?? app.name) missing from "
                    + "the AX list but still on screen — "
                    + "removal refused"
            )
        }
        guard spent < Self.removalRecheckCap else { return }
        removalDistrusted[id] = spent + 1
        let wasIdle = pendingRemovalRecheck.isEmpty
        pendingRemovalRecheck.insert(pid)
        if wasIdle {
            onRemovalDistrust()
        }
    }

    /// Hands the pids owed a distrust follow-up to the scheduled
    /// task and clears the queue (#1157).
    func drainPendingRemovalRecheck() -> Set<pid_t> {
        let pids = pendingRemovalRecheck
        pendingRemovalRecheck = []
        return pids
    }
}
