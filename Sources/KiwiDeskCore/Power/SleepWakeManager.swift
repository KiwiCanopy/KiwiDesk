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
    /// fires. If the set changed while asleep/locked (undock,
    /// monitor power-off), the snapshot's raw frames belong to
    /// dead geometry and the monitor-change re-adopt that
    /// already ran is the truth — replaying on top of it is
    /// what scrambled wakes (#633). Compared as a set: display
    /// *order* may shuffle without meaning a topology change.
    /// The unwired default (`[]` both sides) compares equal, so
    /// the gate stays inert until Bootstrap wires it.
    public var displayFingerprints: @MainActor () -> [String] = { [] }

    private var snapshot: StateSnapshot?
    private var snapshotFingerprints: Set<String> = []
    private var restoreTask: Task<Void, Never>?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] =
        []

    public init() {}

    public func start() {
        guard tokens.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(
            workspace,
            NSWorkspace.willSleepNotification,
            capture: true
        )
        observe(
            workspace,
            NSWorkspace.didWakeNotification,
            capture: false
        )
        let distributed = DistributedNotificationCenter.default()
        observe(
            distributed,
            Notification.Name("com.apple.screenIsLocked"),
            capture: true
        )
        observe(
            distributed,
            Notification.Name("com.apple.screenIsUnlocked"),
            capture: false
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

    // MARK: - Internals

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        capture: Bool
    ) {
        let token = center.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if capture {
                    self?.systemWillRest()
                } else {
                    self?.systemDidReturn()
                }
            }
        }
        tokens.append((center, token))
    }

    /// Internal, not private: the notification observers above
    /// are the production trigger, and tests drive the pair
    /// directly instead of posting to the shared centers.
    func systemWillRest() {
        guard isEnabled else { return }
        restoreTask?.cancel()
        restoreTask = nil
        snapshot = captureState()
        snapshotFingerprints = Set(displayFingerprints())
    }

    func systemDidReturn() {
        guard isEnabled, let saved = snapshot else { return }
        restoreTask?.cancel()
        let delay = restoreDelayMS
        restoreTask = Task { [weak self] in
            let ns = UInt64(delay) * 1_000_000
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled, let self else { return }
            // Re-read at fire time, not at wake: the delay
            // exists precisely so the topology can finish
            // settling first.
            if Set(self.displayFingerprints())
                == self.snapshotFingerprints
            {
                self.restoreState(saved)
            } else {
                self.onLog(
                    "wake restore skipped: display topology "
                        + "changed while away"
                )
            }
            self.snapshot = nil
        }
    }
}
