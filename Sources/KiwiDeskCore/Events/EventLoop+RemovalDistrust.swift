import ApplicationServices

/// The removal-distrust gate (#1157): a sweep close candidate
/// the on-screen census still shows is refused, because the
/// census may REFUSE a removal, never cause one. The argument —
/// the #913 mirror, the asymmetry, the accepted residue — is
/// accessibility.md's.
extension EventLoop {
    /// Fresh one-shot arms one episode may spend. Every counted
    /// arm is a full-delay pass — a refusal that rides an
    /// already-armed one-shot queues without spending — and past
    /// the cap the episode goes quiet rather than polling a
    /// permanently mismatched app (#1157).
    static let removalRecheckCap = 2

    /// Refuses one sweep removal for a window the census still
    /// shows. The first refusal of a continuous-absence episode
    /// logs; a refusal queues a follow-up reconcile while the
    /// episode has arms left (`removalRecheckCap`), so a TRUE
    /// close still compositing at sweep time converges on the
    /// recheck one-shot instead of waiting for the next
    /// incidental pass.
    func refuseRemoval(_ id: WindowID, pid: pid_t, app: AppRef) {
        let spent = removalDistrusted[id]
        if spent == nil {
            onLog(
                "close distrust: w\(id.raw) of "
                    + "\(app.bundleID ?? app.name) missing from "
                    + "the AX list but still on screen — "
                    + "removal refused"
            )
        }
        let arms = spent ?? 0
        removalDistrusted[id] = arms
        guard arms < Self.removalRecheckCap else { return }
        let wasIdle = pendingRemovalRecheck.isEmpty
        pendingRemovalRecheck.insert(pid)
        if wasIdle {
            removalDistrusted[id] = arms + 1
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
