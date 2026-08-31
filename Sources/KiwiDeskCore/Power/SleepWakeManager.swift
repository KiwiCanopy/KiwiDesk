import AppKit
import Foundation

/// Preserves and restores window state across sleep/wake and lock/unlock.
@MainActor
public final class SleepWakeManager {
    public var isEnabled = true
    public var restoreDelayMS = 1500

    public var captureState: @MainActor () -> StateSnapshot? = {
        nil
    }

    public var restoreState: @MainActor (StateSnapshot) -> Void =
        { _ in }

    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// Display topology of a held snapshot, re-read when the
    /// delayed restore fires — replaying onto changed geometry is
    /// what scrambled wakes (#633). Compared as a sorted MULTISET,
    /// never a `Set`: two identical monitors share one
    /// fingerprint, and a `Set` would swallow the loss of one of
    /// them — the most common matched-pair undock
    /// (`WakeFingerprintWiringTests`).
    public var displayFingerprints: @MainActor () -> [String] = { [] }

    /// Diagnostic session presence (`WakeSessionPresenceWiringTests`, #835).
    public var sessionPresence: @MainActor () -> SessionPresence =
        { SessionPresence(session: nil) }

    private var snapshot: StateSnapshot?
    private var snapshotFingerprints: [String] = []
    private var restoreTask: Task<Void, Never>?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] =
        []

    public init() {}

    /// Identifies the transition leg for logging (#835).
    enum Leg: String {
        case sleep, wake, lock, unlock
        /// Driven with no notification behind it — the tests. A
        /// production trigger added later takes a case of its OWN:
        /// an anonymous leg in the log is the evidence gap `Leg`
        /// exists to close, and there is no default parameter so
        /// the choice cannot be made by omission.
        case direct

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

    /// Cancels pending wake/unlock restore and drops held snapshot (#634).
    public func dropHeldSnapshot() {
        restoreTask?.cancel()
        restoreTask = nil
        snapshot = nil
        snapshotFingerprints = []
    }

    /// True if a state snapshot is currently held.
    var holdsSnapshot: Bool { snapshot != nil }

    /// The most recently ARMED replay, for a test to await instead
    /// of polling — the one authority for why polling was wrong
    /// here, which tests.md ▸ "Async tests" cites: swift-testing
    /// starves the shared main actor under a full run (one 10 ms
    /// sleep measured 65 s), so a wall-clock deadline decided by
    /// which continuation drained first (#791). NOT an in-flight
    /// predicate: the task is left uncleared deliberately (clearing
    /// from inside would race a newer arm); `holdsSnapshot` is the
    /// in-flight question. Production must not read either.
    var pendingReplay: Task<Void, Never>? { restoreTask }

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
            let note =
                "\(self.sessionPresence().summary), "
                + self.age(of: saved)
            if self.displayFingerprints().sorted()
                == self.snapshotFingerprints
            {
                self.restoreState(saved)
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

    private func describe(_ snapshot: StateSnapshot?) -> String {
        guard let snapshot else {
            return "nothing (capture returned no state)"
        }
        return "\(snapshot.windows.count) windows in "
            + "\(snapshot.spaces.count) spaces"
    }

    private func age(of snapshot: StateSnapshot) -> String {
        let seconds = Date().timeIntervalSince(snapshot.capturedAt)
        return String(format: "captured %.1fs ago", seconds)
    }
}
