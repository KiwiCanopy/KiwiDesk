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
    /// permanently mismatched app (#1157). The expected-absence
    /// arms (#1145, #1272) spend the SAME arms census-blind, so
    /// their budget is two `KiwiCore.transientRetrackDelay`
    /// passes: ~1.5 s, past the ~1 s switch transition measured
    /// on device (2026-09-01, macOS 26.6.2) in which a carried
    /// window is on no reading, and past the ~0.5 s a fullscreen
    /// transition orders a window out (Zen, 2026-09-05).
    static let removalRecheckCap = 2

    /// Why a vanished window is EXPECTED absent for a beat: the
    /// sticky carry has it in flight (#1145), or a native
    /// fullscreen transition has it ordered out (#1272). Both
    /// spend the one episode ledger; the case names the log line.
    enum ExpectedAbsence {
        case carried
        case fullscreen
    }

    /// Refuses one sweep removal for a window the census still
    /// shows, or one an arm expects absent (`blind`). The first
    /// refusal of a continuous-absence episode logs; a refusal
    /// queues a follow-up reconcile while the episode has arms
    /// left (`removalRecheckCap`), so a TRUE close still
    /// compositing at sweep time converges on the recheck
    /// one-shot instead of waiting for the next incidental pass.
    func refuseRemoval(
        _ id: WindowID,
        pid: pid_t,
        app: AppRef,
        blind: ExpectedAbsence? = nil
    ) {
        let spent = removalDistrusted[id]
        if spent == nil {
            let cause: String
            switch blind {
            case .carried:
                cause = "carried across Desktops (#1145)"
            case .fullscreen:
                cause = "in a native fullscreen transition (#1272)"
            case nil:
                cause = "still on screen"
            }
            onLog(
                "close distrust: w\(id.raw) of "
                    + "\(app.bundleID ?? app.name) missing from "
                    + "the AX list but \(cause) — removal refused"
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

    /// The expected-absence arms (#1145, #1272). A window an arm
    /// expects present is refused outright while the census shows
    /// it (#1157's own rule), and census-blind while the ONE
    /// episode ledger still has arms (`removalRecheckCap`), so
    /// every blind refusal is followed by the recheck that can
    /// end it. State AND registration are kept, so the reconcile
    /// that lists the window again re-elements the same id rather
    /// than re-creating it. False outside every arm and past the
    /// cap: a genuine close (accessibility.md).
    func refusesExpectedRemoval(
        _ id: WindowID,
        pid: pid_t,
        app: AppRef,
        census: () -> Set<WindowID>
    ) -> Bool {
        guard let arm = expectedAbsence(of: id) else { return false }
        if census().contains(id) {
            refuseRemoval(id, pid: pid, app: app)
            return true
        }
        guard removalDistrusted[id, default: 0] < Self.removalRecheckCap
        else { return false }
        refuseRemoval(id, pid: pid, app: app, blind: arm)
        return true
    }

    /// Which arm, if any, expects `id` present now — the one
    /// reading the sweep and the destroy notification's deferral
    /// share. Never the switch grace: a slow app's element dies
    /// well after it (device, 2026-09-02), a fullscreen exit's
    /// sweep can run inside it, and a switch alone says nothing
    /// about a window nobody moved.
    func expectedAbsence(of id: WindowID) -> ExpectedAbsence? {
        if carriedRemovalArmIsOpen(for: id) { return .carried }
        if fullscreenRemovalArmIsOpen(for: id) { return .fullscreen }
        return nil
    }

    /// The carried arm (#1145): the carry has this window IN
    /// FLIGHT — moved within `KiwiCore.inFlightWindow`, the seam's
    /// own reading.
    func carriedRemovalArmIsOpen(for id: WindowID) -> Bool {
        carriedWindows().contains(id)
    }

    /// The fullscreen arm (#1272, accessibility.md): EXIT is read
    /// off the loop's own last reading (`detectedFullscreen`),
    /// ENTER off the compositor's word through
    /// `fullscreenSpaceHosts`. "Still hosted" alone is never the
    /// signal — a closed window lingers on its Desktop's Space —
    /// so only the fullscreen half tells the transition from a
    /// close.
    func fullscreenRemovalArmIsOpen(for id: WindowID) -> Bool {
        detectedFullscreen[id] == true || fullscreenSpaceHosts(id)
    }

    /// Hands the pids owed a distrust follow-up to the scheduled
    /// task and clears the queue (#1157).
    func drainPendingRemovalRecheck() -> Set<pid_t> {
        let pids = pendingRemovalRecheck
        pendingRemovalRecheck = []
        return pids
    }
}
