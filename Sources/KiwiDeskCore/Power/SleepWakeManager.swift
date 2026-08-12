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
    /// **Diagnostic only — nothing branches on it (#835.)** A
    /// lock → lid → unlock cycle produces two rest events and two
    /// return events, and the open question is whether the replay
    /// fires while the screen is still locked, leaving the unlock
    /// leg with nothing to replay. No failing cycle has been
    /// captured with logging on, so this ships the observation
    /// and not the fix: a predicate chosen before that capture is
    /// a guess with tests around it. It records BOTH facts
    /// because the fix's obvious predicate is the wrong one —
    /// `kCGSessionOnConsoleKey` reports fast user switching, not
    /// the lock, and `SessionPresence` carries the measurement.
    ///
    /// Live by default, like every other host read here; a suite
    /// that wants a quiet, deterministic session assigns its own.
    public var sessionPresence: @MainActor () -> SessionPresence =
        { .live() }

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
        /// Driven with no notification behind it: the tests, and
        /// the one value production never logs.
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
    func systemWillRest(_ leg: Leg = .direct) {
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

    func systemDidReturn(_ leg: Leg = .direct) {
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
