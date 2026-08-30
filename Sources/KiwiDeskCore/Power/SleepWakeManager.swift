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

    /// Display topology fingerprints; tested via `WakeFingerprintWiringTests`
    /// (#633).
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

    /// Armed replay task for tests to await (#791).
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
