import ApplicationServices

/// The carried-window arm of the removal-distrust gate (#1145).
/// A window sticky reach carries is EXPECTED present after a
/// Desktop switch — the bridge MOVE puts it on the arriving
/// Desktop — but for the transition's beat it is on NO reading:
/// its AX element dies as it leaves the visible Space and the
/// compositor census has not composited it yet. So its vanish is
/// refused inside the switch grace too, where the #1157 gate
/// stands down, on a bounded census-blind budget.
struct CarriedRemovalGate {
    /// Census-blind refusals one continuous-absence episode may
    /// spend. The dark beat measured ~1 s on device (2026-09-01,
    /// macOS 26.6.2) and each arm is one sweep of that episode
    /// plus its recheck, so three outlast the beat with margin
    /// while a genuinely closed carried window still converges
    /// on the distrust's own one-shots.
    static let armCap = 3

    /// Which windows the carry follows — the core's reading,
    /// wired in `KiwiCore+Bootstrap`; the empty default keeps
    /// every harness inert.
    var carried: () -> Set<WindowID> = { [] }

    /// Census-blind arms spent per window, reset when the window
    /// is AX-listed again and cleared with its registration.
    var arms: [WindowID: Int] = [:]
}

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

    /// The carried arm (#1145): refuses a carried window's
    /// removal — outright while the census still shows it, and
    /// on an arm while it shows nothing — keeping its state AND
    /// its registration, so the reconcile that lists it again
    /// re-elements the same id instead of re-creating it. False
    /// for a window the carry does not follow, and for a carried
    /// one whose arms are spent: a genuine close.
    func refusesCarriedRemoval(
        _ id: WindowID,
        pid: pid_t,
        app: AppRef,
        census: () -> Set<WindowID>
    ) -> Bool {
        guard carriedRemoval.carried().contains(id) else {
            return false
        }
        if census().contains(id) {
            refuseRemoval(id, pid: pid, app: app)
            return true
        }
        let arms = carriedRemoval.arms[id, default: 0]
        guard arms < CarriedRemovalGate.armCap else { return false }
        carriedRemoval.arms[id] = arms + 1
        refuseRemoval(id, pid: pid, app: app, carried: true)
        return true
    }

    /// Hands the pids owed a distrust follow-up to the scheduled
    /// task and clears the queue (#1157).
    func drainPendingRemovalRecheck() -> Set<pid_t> {
        let pids = pendingRemovalRecheck
        pendingRemovalRecheck = []
        return pids
    }
}
