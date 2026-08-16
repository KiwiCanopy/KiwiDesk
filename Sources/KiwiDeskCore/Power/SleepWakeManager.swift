import AppKit
import Foundation

/// Preserves window state across sleep/wake and lock/unlock.
///
/// macOS tends to scramble window positions when displays go
/// away during these transitions. This manager snapshots the
/// state before the system sleeps or locks, and restores it
/// after waking — delayed by `restoreDelayMS` so displays can
/// finish reconnecting first.
@MainActor
public final class SleepWakeManager {
    /// `enable_wake_restore`: master toggle.
    public var isEnabled = true

    /// `wake_restore_delay_ms`: wait before restoring so the
    /// display topology can settle. Default 1500 ms.
    public var restoreDelayMS = 1500

    /// Captures the state to preserve (nil skips the cycle).
    public var captureState: @MainActor () -> StateSnapshot? = {
        nil
    }

    /// Re-applies a previously captured state.
    public var restoreState: @MainActor (StateSnapshot) -> Void =
        { _ in }

    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// The display topology a held snapshot belongs to,
    /// captured beside it and re-read when the delayed restore
    /// fires. If it changed while asleep/locked (undock,
    /// monitor power-off), the snapshot's raw frames belong to
    /// dead geometry and the monitor-change re-adopt that
    /// already ran is the truth — replaying on top of it is
    /// what scrambled wakes (#633). Compared as a sorted
    /// multiset, never a `Set`: display *order* may shuffle
    /// without meaning a topology change, but two identical
    /// monitors share one fingerprint, and a `Set` would
    /// swallow the loss of one of them — the most common
    /// matched-pair undock. The unwired default (`[]` both
    /// sides) compares equal, so the gate stays inert until
    /// Bootstrap wires it; `WakeFingerprintWiringTests` probes
    /// that wiring on a live core.
    public var displayFingerprints: @MainActor () -> [String] = { [] }

    /// What macOS says about the login session, read where the
    /// replay decides.
    ///
    /// **Diagnostic only — nothing branches on it (#835).** The
    /// mechanism it exists to settle, and why BOTH of its facts
    /// are recorded rather than the one the issue proposed, are
    /// argued once on `SessionPresence`.
    ///
    /// Inert by default and wired in `KiwiCore+Bootstrap`, like
    /// the three seams above it — never live-by-default. An
    /// unwired live read would reach the host from every suite
    /// that drives a return leg, which is a residue `tests.md`
    /// does not carry; the inert default reports "unknown" on
    /// every axis, which is an honest thing for a diagnostic to
    /// say and a useless thing to ship, so the wiring is probed
    /// on a live core by `WakeSessionPresenceWiringTests` — the
    /// `displayFingerprints` precedent, and the same shipped-
    /// inert-seam class the log-seam guards exist for.
    public var sessionPresence: @MainActor () -> SessionPresence =
        { SessionPresence(session: nil) }

    private var snapshot: StateSnapshot?
    /// Sorted at capture; see `displayFingerprints`.
    private var snapshotFingerprints: [String] = []
    private var restoreTask: Task<Void, Never>?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] =
        []

    public init() {}

    /// Which notification drove a rest or a return.
    ///
    /// Carried into every log line so a lock → lid → unlock cycle
    /// reads as the four events it is, rather than as two
    /// anonymous pairs — which is the whole of what the #835 log
    /// could not say.
    enum Leg: String {
        case sleep, wake, lock, unlock
        /// Driven with no notification behind it — the tests.
        /// A production trigger added later takes a case of its
        /// own rather than this one: an anonymous leg in the log
        /// is the exact evidence gap `Leg` exists to close, and
        /// the parameter carries no default so the choice cannot
        /// be made by omission.
        case direct

        /// Whether this leg captures (a rest) or replays (a
        /// return). Derived from the leg rather than passed
        /// beside it, so a leg added later cannot be wired to
        /// the wrong half of the pair.
        var isRest: Bool { self == .sleep || self == .lock }
    }

    public func start() {
        guard tokens.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(
            workspace,
            NSWorkspace.willSleepNotification,
            leg: .sleep
        )
        observe(
            workspace,
            NSWorkspace.didWakeNotification,
            leg: .wake
        )
        let distributed = DistributedNotificationCenter.default()
        observe(
            distributed,
            Notification.Name("com.apple.screenIsLocked"),
            leg: .lock
        )
        observe(
            distributed,
            Notification.Name("com.apple.screenIsUnlocked"),
            leg: .unlock
        )
    }

    public func stop() {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
        tokens = []
        restoreTask?.cancel()
        restoreTask = nil
    }

    /// Drops a snapshot held for a pending wake/unlock replay,
    /// cancelling the replay — the tier-1 escape hatch's
    /// in-flight half (#634). Observers stay armed; the next
    /// rest/return cycle captures fresh.
    public func dropHeldSnapshot() {
        restoreTask?.cancel()
        restoreTask = nil
        snapshot = nil
        snapshotFingerprints = []
    }

    /// Whether a rest capture is currently held for replay.
    /// Internal observability for the tier-1 discard pin — the
    /// replay itself hides behind an awaited `Task`, so a test
    /// asserting "nothing replayed" synchronously passes even
    /// when the drop is broken; this reads the held state
    /// directly. Production must not read it: the held
    /// snapshot's one consumer is the return leg above.
    var holdsSnapshot: Bool { snapshot != nil }

    /// The most recently ARMED replay, for a test to await
    /// instead of polling for its effect.
    ///
    /// This is the one authority for why polling was wrong here;
    /// `tests.md` ▸ "Async tests" and the two wake suites cite it
    /// rather than restating the measurement. The poll it
    /// replaces bounded a 30 s WALL-CLOCK deadline, and wall
    /// clock is the wrong instrument: swift-testing runs suites
    /// concurrently, so under a full run the shared main actor is
    /// starved and one 10 ms `Task.sleep` resumption measured
    /// 65 s. Past the deadline the loop exits without giving the
    /// replay's continuation a turn, so the result came down to
    /// which continuation drained first — which is why the
    /// reported failure hit three tests of four rather than all
    /// four, and why it looked like shared state with the running
    /// app when it was CPU contention (#791).
    ///
    /// **Not an in-flight predicate.** The task is not cleared
    /// when its body finishes, so a non-nil value means "one was
    /// armed since the last `stop()` / `dropHeldSnapshot()`", and
    /// awaiting after a return leg that early-returned awaits the
    /// PREVIOUS cycle's finished task — vacuously. `holdsSnapshot`
    /// is the in-flight question. It is left uncleared
    /// deliberately: clearing from inside the task would race a
    /// newer arm into dropping it.
    ///
    /// Production must not read it: the replay's one consumer is
    /// the return leg that armed it.
    var pendingReplay: Task<Void, Never>? { restoreTask }

    // MARK: - Internals

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        leg: Leg
    ) {
        let token = center.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if leg.isRest {
                    self?.systemWillRest(leg)
                } else {
                    self?.systemDidReturn(leg)
                }
            }
        }
        tokens.append((center, token))
    }

    /// Internal, not private: the notification observers above
    /// are the production trigger, and tests drive the pair
    /// directly instead of posting to the shared centers.
    func systemWillRest(_ leg: Leg) {
        guard isEnabled else { return }
        restoreTask?.cancel()
        restoreTask = nil
        let replaced = snapshot != nil
        snapshot = captureState()
        snapshotFingerprints = displayFingerprints().sorted()
        onLog(
            "wake restore: \(leg.rawValue) captured "
                + describe(snapshot)
                + (replaced ? ", replacing a held capture" : "")
        )
    }

    func systemDidReturn(_ leg: Leg) {
        guard isEnabled else { return }
        // The silent arm the #835 log could not distinguish from
        // a healthy cycle: if the wake leg's replay has already
        // fired and cleared the capture, the unlock leg lands
        // here with nothing left to do, and the log said nothing
        // either way.
        guard let saved = snapshot else {
            onLog(
                "wake restore: \(leg.rawValue) found no held "
                    + "capture — nothing to replay"
            )
            return
        }
        restoreTask?.cancel()
        let delay = restoreDelayMS
        onLog(
            "wake restore: \(leg.rawValue) armed a replay in "
                + "\(delay)ms (\(sessionPresence().summary))"
        )
        restoreTask = Task { [weak self] in
            let ns = UInt64(delay) * 1_000_000
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled, let self else { return }
            // Re-read at fire time, not at wake: the delay
            // exists precisely so the topology can finish
            // settling first.
            let note =
                "\(self.sessionPresence().summary), "
                + self.age(of: saved)
            if self.displayFingerprints().sorted()
                == self.snapshotFingerprints
            {
                self.restoreState(saved)
                // The positive line #835 asked for. Without it a
                // silent log cannot tell "restored correctly"
                // from "never restored", so no capture of a
                // failing cycle could be decisive.
                self.onLog(
                    "wake restore: \(leg.rawValue) replayed "
                        + self.describe(saved) + " (\(note))"
                )
            } else {
                self.onLog(
                    "wake restore skipped: display topology "
                        + "changed while away (\(note))"
                )
            }
            self.snapshot = nil
        }
    }

    /// `12 windows in 3 spaces`, or why there was nothing.
    private func describe(_ snapshot: StateSnapshot?) -> String {
        guard let snapshot else {
            return "nothing (capture returned no state)"
        }
        return "\(snapshot.windows.count) windows in "
            + "\(snapshot.spaces.count) spaces"
    }

    /// How stale the replayed capture is. The mechanism under
    /// suspicion needs the return to outlive `restoreDelayMS`,
    /// so the gap between capture and replay is evidence.
    private func age(of snapshot: StateSnapshot) -> String {
        let seconds = Date().timeIntervalSince(snapshot.capturedAt)
        return String(format: "captured %.1fs ago", seconds)
    }
}
