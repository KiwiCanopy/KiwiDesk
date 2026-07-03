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

    private var snapshot: StateSnapshot?
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

    private func systemWillRest() {
        guard isEnabled else { return }
        restoreTask?.cancel()
        restoreTask = nil
        snapshot = captureState()
    }

    private func systemDidReturn() {
        guard isEnabled, let saved = snapshot else { return }
        restoreTask?.cancel()
        let delay = restoreDelayMS
        restoreTask = Task { [weak self] in
            let ns = UInt64(delay) * 1_000_000
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            self?.restoreState(saved)
            self?.snapshot = nil
        }
    }
}
