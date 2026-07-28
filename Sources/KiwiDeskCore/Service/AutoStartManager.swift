import Foundation

/// The **auto-start composition root** (#576): the one place that
/// folds KiwiDesk's two independent launch mechanisms — the
/// `SMAppService` login item (`LoginItemManager`) and the
/// crash-supervising `kiwidesk service` LaunchAgent
/// (`ServiceManager`) — into a single `AutoStartLevel`. It is the
/// GUI-side analog of what `CLIMain.runService` is for the CLI:
/// each subsystem stays decoupled (`ServiceManager` never imports
/// `SMAppService`), and this facade owns the coupling instead of
/// the view.
///
/// Why fold, not two toggles: the service is `RunAtLoad` +
/// `KeepAlive` as one indivisible unit, so "restart on crash" is a
/// *superset* of "open at login" — a pair of read-through toggles
/// could render the contradictory *Open at Login: OFF + Restart:
/// ON*. One control over one merged status makes that
/// unrepresentable.
///
/// **Async discipline (architect-gated).** `ServiceManager`'s
/// launchctl verbs are blocking `Process` spawns; running them in a
/// SwiftUI `body`/`onAppear` on the main thread is an AGENTS.md
/// violation. So `current()` / `set(_:)` are `async` and do their
/// work on a detached background task — the GUI shows a transient
/// pending state and publishes the result to `@State` on main.
///
/// **Read-through.** No cached bool: the level is always derived
/// from a fresh dual read, and `set(_:)` re-reads after applying,
/// exactly as `LoginItemManager.setEnabled` returns `current`. That
/// one live source keeps the GUI and the `kiwidesk service` CLI in
/// sync with no second store to drift.
///
/// Core returns *structure* (`AutoStartStatus`); the GUI narrates
/// the level and any unavailable/approval caption at its own
/// boundary (#96).
public enum AutoStartManager {
    /// The current level plus the availability/approval facts the
    /// GUI needs, read off the main actor.
    public static func current() async -> AutoStartStatus {
        await Task.detached(priority: .userInitiated) { read() }
            .value
    }

    /// Applies a level (registering/unregistering the login item
    /// and starting/stopping the service as that level demands),
    /// then re-reads so the control adopts OS truth rather than the
    /// attempted flip. Off the main actor.
    @discardableResult
    public static func set(
        _ level: AutoStartLevel
    ) async -> AutoStartStatus {
        await Task.detached(priority: .userInitiated) {
            apply(level)
            return read()
        }.value
    }

    // MARK: - Dual read & apply (blocking — call off main)

    /// One fresh dual read: the live login-item state + the
    /// service's launchd state, folded to a level. Blocking
    /// (`currentStatus` spawns launchctl) — callers run it detached.
    static func read() -> AutoStartStatus {
        status(
            login: LoginItemManager.current,
            service: ServiceManager.currentStatus()
        )
    }

    /// Drives the two mechanisms to match `level`. The service is
    /// the superset, so the auto-restart level keeps the login item
    /// on *and* loads the service; the plain login level stops the
    /// service; off clears both. Results are discarded — the
    /// following re-read reports what actually took (a launchctl or
    /// `SMAppService` failure is logged by the callee and simply
    /// leaves that mechanism where it was).
    static func apply(_ level: AutoStartLevel) {
        switch level {
        case .off:
            LoginItemManager.setEnabled(false)
            _ = ServiceManager.stop()
        case .atLogin:
            LoginItemManager.setEnabled(true)
            _ = ServiceManager.stop()
        case .atLoginWithAutoRestart:
            LoginItemManager.setEnabled(true)
            _ = ServiceManager.start()
        }
    }

    // MARK: - Pure mapping (unit-tested)

    /// Folds the two subsystem states into the GUI-facing status.
    /// Pure over its inputs so the mapping is testable without
    /// touching `SMAppService` or launchctl.
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

    /// The level the merged state reads as. A loaded service wins:
    /// it sets `RunAtLoad` (so it launches at login) *and*
    /// `KeepAlive` (so it restarts on crash), the auto-restart
    /// level's exact promise. Otherwise the login item alone means
    /// plain at-login, and neither means off.
    static func level(
        loginOn: Bool,
        serviceLoaded: Bool
    ) -> AutoStartLevel {
        if serviceLoaded { return .atLoginWithAutoRestart }
        return loginOn ? .atLogin : .off
    }
}

/// The three auto-start levels the folded control offers (#576),
/// ordered off → most. `atLoginWithAutoRestart` is a superset of
/// `atLogin` — it also relaunches KiwiDesk if it crashes.
public enum AutoStartLevel: Equatable, Sendable, CaseIterable {
    /// Neither mechanism: KiwiDesk never starts itself.
    case off
    /// Login item on: launches at login, no crash supervision.
    case atLogin
    /// The `kiwidesk service` LaunchAgent: launches at login and
    /// restarts on crash (`RunAtLoad` + `KeepAlive`).
    case atLoginWithAutoRestart
}

/// The structure Core hands the GUI for the auto-start control: the
/// current level plus the two facts that shape its rendering —
/// whether the upper levels are unavailable (grey, don't hide), and
/// whether the login item is awaiting the user's approval.
public struct AutoStartStatus: Equatable, Sendable {
    /// The level the merged state currently reads as.
    public let level: AutoStartLevel
    /// Set when the running copy can't register a login item — a
    /// bare binary or a translocated download. Disables levels 2
    /// *and* 3 (both need a stable `.app` path: level 2 is the
    /// `SMAppService` item, level 3 a LaunchAgent that would point
    /// at an ephemeral path), leaving only "Never" selectable. The
    /// reason picks the caption, reusing the login-item strings.
    public let unavailable: LoginItemUnavailable?
    /// The login item is registered but macOS needs the user to
    /// confirm it in System Settings ▸ Login Items — surfaced as
    /// the same jump the login toggle showed.
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

    /// Whether the upper two levels are selectable — false when the
    /// running copy can't register.
    public var registerable: Bool { unavailable == nil }
}
