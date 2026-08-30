import Foundation
import ServiceManagement

/// Authority for KiwiDesk login item registration via `SMAppService.mainApp`
/// (#342, #96).
public enum LoginItemManager {
    /// Live registration state mapped from the OS.
    public static var current: LoginItemState {
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

    /// Pure mapping from OS `SMAppService.Status` to `LoginItemState`.
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
