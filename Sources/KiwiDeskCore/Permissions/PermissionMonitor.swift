import AppKit
import ApplicationServices

/// Polls Accessibility permission and reports transitions.
///
/// Used by the onboarding wizard (waiting for the user to grant
/// permission) and at runtime to detect mid-session revocation.
@MainActor
public final class PermissionMonitor {
    /// Fired on every transition (granted <-> revoked).
    public var onChange: @MainActor (Bool) -> Void = { _ in }

    public private(set) var isTrusted: Bool
    private var timer: Timer?
    private let interval: TimeInterval

    public init(interval: TimeInterval = 2.0) {
        self.interval = interval
        self.isTrusted = AXHelper.isTrusted()
    }

    /// Starts polling. Safe to call repeatedly.
    public func start() {
        guard timer == nil else { return }
        let timer = Timer(
            timeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Opens System Settings at Privacy & Security >
    /// Accessibility.
    public static func openSystemSettings() {
        let url =
            "x-apple.systempreferences:"
            + "com.apple.preference.security"
            + "?Privacy_Accessibility"
        guard let target = URL(string: url) else { return }
        NSWorkspace.shared.open(target)
    }

    private func poll() {
        let trusted = AXHelper.isTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        onChange(trusted)
    }
}
