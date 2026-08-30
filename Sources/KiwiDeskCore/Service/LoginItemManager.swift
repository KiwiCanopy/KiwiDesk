import Foundation
import ServiceManagement

/// Authority for the KiwiDesk login item via `SMAppService`
/// (#342, #96). Not the only auto-start: the `kiwidesk service`
/// LaunchAgent sets `RunAtLoad`, so it also launches at login,
/// invisibly to this toggle — the #196 instance lock dedupes the
/// two into one process. Read-through: never a cached bool, so a
/// change made in System Settings is seen on the next poll.
public enum LoginItemManager {
    /// Live registration state mapped from the OS.
    public static var current: LoginItemState {
        // Location first, unconditionally: a copy at a path that
        // cannot be a stable login item is `.unavailable` whatever
        // `SMAppService` reports — even if a prior install left a
        // stale registration.
        if let reason = unavailableReason(for: Bundle.main.bundleURL) {
            return .unavailable(reason)
        }
        return state(from: SMAppService.mainApp.status)
    }

    /// Why bundle at `url` cannot register (nil if registerable).
    static func unavailableReason(
        for url: URL
    ) -> LoginItemUnavailable? {
        guard url.pathExtension == "app" else { return .notBundled }
        if url.path.contains("/AppTranslocation/") {
            return .translocated
        }
        return nil
    }

    /// Registers or unregisters the app as a login item and returns result.
    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> LoginItemState {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog(
                "KiwiDesk: login-item %@ failed: %@",
                enabled ? "register" : "unregister",
                String(describing: error)
            )
        }
        return current
    }

    /// Opens System Settings ▸ General ▸ Login Items.
    public static func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Pure mapping from the OS status. `.notFound` folds to
    /// `.notRegistered` — it is the ordinary pre-registration
    /// state for `mainApp` (verified on 26.x), so a registerable
    /// app offers to turn it on rather than greying; the terminal
    /// `.notFound` is caught by `current`'s location check. An
    /// unknown future status also folds there: offer, log, re-read
    /// — the switch flips back cleanly on failure.
    static func state(from status: SMAppService.Status) -> LoginItemState {
        switch status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notRegistered
        @unknown default: return .notRegistered
        }
    }
}

/// Registration states for login item control (#96).
public enum LoginItemState: Equatable, Sendable {
    /// Not registered as login item.
    case notRegistered
    /// Registered and active.
    case enabled
    /// User enabled, awaiting approval in System Settings.
    case requiresApproval
    /// Registration unavailable from current launch path (#171).
    case unavailable(LoginItemUnavailable)

    /// True if enabled or awaiting approval.
    public var isOn: Bool {
        self == .enabled || self == .requiresApproval
    }

    /// Unavailability reason if unavailable, nil otherwise.
    public var unavailableReason: LoginItemUnavailable? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

/// Reasons why `SMAppService` cannot register the running binary (#96).
public enum LoginItemUnavailable: Hashable, Sendable {
    /// Bare executable without an `.app` bundle wrapper.
    case notBundled
    /// Gatekeeper-translocated read-only copy.
    case translocated
}
