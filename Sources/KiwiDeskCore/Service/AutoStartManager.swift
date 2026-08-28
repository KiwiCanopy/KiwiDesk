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
/// Why one merged level and not two independent flags: the
/// service is `RunAtLoad` + `KeepAlive` as one indivisible unit,
/// so "restart on crash" is a *superset* of "open at login", and
/// the pair *Open at Login: OFF + Restart: ON* names no reachable
/// state. #576 kept that honest by shipping one three-level
/// picker.
///
/// **The GUI now draws two rows again (#678 item 16), and the
/// constraint did not move with it.** What makes the pair
/// impossible is no longer the shape of the control — a view can
/// hold two toggles in any combination — but
/// `AutoStartLevel.level(openAtLogin:restartOnCrash:)`, which
/// discards the restart flag when login is off. Read that as the
/// invariant's home: the Advanced row's greying is a courtesy to
/// the reader, and this type is what a CLI verb, a restored
/// preference or a test hits when no view is involved. Do not
/// re-derive the pair anywhere else.
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

    /// Drives the LOGIN ITEM alone, leaving the service exactly
    /// as it is, and re-reads the folded status (#1071).
    ///
    /// `set(_:)` takes a LEVEL, and the level ladder stops the
    /// service on both `.off` and `.atLogin` — correct for a
    /// caller choosing a level, wrong for the Settings switch,
    /// which owns the login item and nothing else since #1071.
    /// Routing the GUI here means it cannot unload a user's
    /// supervision agent even from a stale read of the status,
    /// because there is no code path from this function to
    /// `ServiceManager`.
    public static func setLoginItem(
        _ enabled: Bool
    ) async -> AutoStartStatus {
        await Task.detached(priority: .userInitiated) {
            _ = LoginItemManager.setEnabled(enabled)
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

    // MARK: - The two rows the GUI draws (#678 item 16)

    /// Whether KiwiDesk starts itself at login.
    public var opensAtLogin: Bool { self != .off }

    /// Whether it is also supervised and relaunched on a crash.
    public var restartsOnCrash: Bool {
        self == .atLoginWithAutoRestart
    }

    /// The level a (login, restart) PAIR means — and the one place
    /// the impossible pair is refused (#678 item 16).
    ///
    /// Turn 14b draws two rows where #576 shipped one three-level
    /// picker. #576's reason has not gone away: the LaunchAgent
    /// writes `RunAtLoad` and `KeepAlive` as one indivisible unit,
    /// so "restart on crash" is a SUPERSET of "open at login" and
    /// the pair *login OFF + restart ON* names no reachable
    /// state. What changed is the presentation, not the
    /// constraint.
    ///
    /// So the constraint moves here, where it is total: with
    /// login off the restart flag is DISCARDED rather than
    /// honoured, and no caller can express the contradiction
    /// whatever its two toggles say. The Advanced row also greys
    /// while login is off, but `gui.md` is explicit that a grey
    /// is never the sole gate on a side effect — this is the
    /// other half, and it is the half that holds when a future
    /// caller (a CLI verb, a restored preference, a test) never
    /// passes through the view at all.
    public static func level(
        openAtLogin: Bool,
        restartOnCrash: Bool
    ) -> AutoStartLevel {
        guard openAtLogin else { return .off }
        return restartOnCrash ? .atLoginWithAutoRestart : .atLogin
    }
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
