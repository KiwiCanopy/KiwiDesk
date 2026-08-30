import Foundation

/// Auto-start composition root folding `SMAppService` and LaunchAgent into
/// `AutoStartLevel` (#576, #678, #1071, #96).
public enum AutoStartManager {
    /// Current status and availability, detached off main actor.
    public static func current() async -> AutoStartStatus {
        await Task.detached(priority: .userInitiated) { read() }
            .value
    }

    /// Drives the login item alone and returns updated status (#1071).
    public static func setLoginItem(
        _ enabled: Bool
    ) async -> AutoStartStatus {
        await Task.detached(priority: .userInitiated) {
            _ = LoginItemManager.setEnabled(enabled)
            return read()
        }.value
    }

    /// Blocking dual read combining login item and launchd service state.
    static func read() -> AutoStartStatus {
        status(
            login: LoginItemManager.current,
            service: ServiceManager.currentStatus()
        )
    }

    /// Pure mapping from subsystem states to GUI status.
    static func status(
        login: LoginItemState,
        service: ServiceStatus
    ) -> AutoStartStatus {
        AutoStartStatus(
            level: level(
                loginOn: login.isOn,
                serviceLoaded: service.isLoaded
            ),
            unavailable: login.unavailableReason,
            requiresApproval: login == .requiresApproval
        )
    }

    /// Derives level from flags (service loaded > login item on > off).
    static func level(
        loginOn: Bool,
        serviceLoaded: Bool
    ) -> AutoStartLevel {
        if serviceLoaded { return .atLoginWithAutoRestart }
        return loginOn ? .atLogin : .off
    }
}

/// Three auto-start levels (#576), ordered off → most.
public enum AutoStartLevel: Equatable, Sendable, CaseIterable {
    /// Never start automatically.
    case off
    /// Launch at login via login item.
    case atLogin
    /// Launch at login and supervise crash restarts via LaunchAgent.
    case atLoginWithAutoRestart

    /// Whether KiwiDesk starts at login.
    public var opensAtLogin: Bool { self != .off }

    /// Whether KiwiDesk restarts on crash.
    public var restartsOnCrash: Bool {
        self == .atLoginWithAutoRestart
    }

    /// The level a (login, restart) pair means — and the ONE place
    /// the impossible pair (login OFF + restart ON) is refused
    /// (#678 item 16): with login off the restart flag is
    /// DISCARDED. The Advanced row's grey is a courtesy; this is
    /// the half that holds for a CLI verb, a restored preference
    /// or a test that never passes the view. Do not re-derive the
    /// pair anywhere else.
    public static func level(
        openAtLogin: Bool,
        restartOnCrash: Bool
    ) -> AutoStartLevel {
        guard openAtLogin else { return .off }
        return restartOnCrash ? .atLoginWithAutoRestart : .atLogin
    }
}

/// Auto-start status for GUI rendering (#96).
public struct AutoStartStatus: Equatable, Sendable {
    public let level: AutoStartLevel
    public let unavailable: LoginItemUnavailable?
    public let requiresApproval: Bool

    public init(
        level: AutoStartLevel,
        unavailable: LoginItemUnavailable?,
        requiresApproval: Bool
    ) {
        self.level = level
        self.unavailable = unavailable
        self.requiresApproval = requiresApproval
    }

    /// True if auto-start registration is supported in this environment.
    public var registerable: Bool { unavailable == nil }
}
