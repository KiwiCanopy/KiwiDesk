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
    /// permanently mismatched app (#1157). The carried arm
    /// (#1145) spends the SAME arms census-blind, so its budget is
    /// two `KiwiCore.transientRetrackDelay` passes: ~1.5 s, past
    /// the ~1 s switch transition measured on device (2026-09-01,
    /// macOS 26.6.2) in which a carried window is on no reading.
    static let removalRecheckCap = 2

    /// Refuses one sweep removal for a window the census still
    /// shows. The first refusal of a continuous-absence episode
    /// logs; a refusal queues a follow-up reconcile while the
    /// episode has arms left (`removalRecheckCap`), so a TRUE
    /// close still compositing at sweep time converges on the
    /// recheck one-shot instead of waiting for the next
    /// incidental pass.
    func refuseRemoval(
        _ id: WindowID,
        pid: pid_t,
        app: AppRef,
        carried: Bool = false
    ) {
        let spent = removalDistrusted[id]
        if spent == nil {
            onLog(
                "close distrust: w\(id.raw) of "
                    + "\(app.bundleID ?? app.name) missing from "
                    + "the AX list but "
                    + (carried
                        ? "carried across Desktops (#1145)"
                        : "still on screen")
                    + " — removal refused"
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

    /// The carried arm (#1145). A window sticky reach carries is
    /// EXPECTED present after a Desktop switch — the bridge MOVE
    /// puts it on the arriving Desktop — but for the transition's
    /// beat it is on NO reading: its AX element dies as it leaves
    /// the visible Space and the census has not composited it
    /// yet. So its removal is refused inside the switch grace
    /// too — outright while the census shows it (#1157's own
    /// rule), and census-blind while the ONE episode ledger still
    /// has arms (`removalRecheckCap`), so every blind refusal is
    /// followed by the recheck that can end it. State AND
    /// registration are kept, so the reconcile that lists the
    /// window again re-elements the same id rather than
    /// re-creating it. False for a window the carry does not
    /// follow, outside `carriedRemovalArmIsOpen`'s window, and
    /// past the cap: a genuine close (accessibility.md, #1145).
    func refusesCarriedRemoval(
        _ id: WindowID,
        pid: pid_t,
        app: AppRef,
        census: () -> Set<WindowID>
    ) -> Bool {
        guard carriedRemovalArmIsOpen(for: id) else { return false }
        if census().contains(id) {
            refuseRemoval(id, pid: pid, app: app)
            return true
        }
        guard removalDistrusted[id, default: 0] < Self.removalRecheckCap
        else { return false }
        refuseRemoval(id, pid: pid, app: app, carried: true)
        return true
    }

    /// Whether the carried arm may rule this window's vanish now:
    /// the carry follows it, and a Desktop switch is in flight or
    /// the window already has an open episode — ANY episode, so a
    /// #1157 census episode on a carried window buys a later
    /// genuine close up to the cap of blind refusals, bounded and
    /// converging. The one reading the sweep and the destroy
    /// notification's deferral share. The grace is stamped by the
    /// NSWorkspace switch notification; a carried window's
    /// destroyed element landing BEFORE that stamp takes the
    /// ordinary departure and returns through the arrival rule
    /// with its scope restored from the sticky intent memory —
    /// slot and pin not kept, the residue
    /// `docs/accepted-limitations.md` records.
    func carriedRemovalArmIsOpen(for id: WindowID) -> Bool {
        carriedWindows().contains(id)
            && (isWithinSpaceSwitchGrace()
                || removalDistrusted[id] != nil)
    }

    /// Hands the pids owed a distrust follow-up to the scheduled
    /// task and clears the queue (#1157).
    func drainPendingRemovalRecheck() -> Set<pid_t> {
        let pids = pendingRemovalRecheck
        pendingRemovalRecheck = []
        return pids
    }
}
