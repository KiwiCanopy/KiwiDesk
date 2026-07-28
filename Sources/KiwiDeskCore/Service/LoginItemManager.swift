import Foundation
import ServiceManagement

/// The authority for the KiwiDesk **login item** (#342).
///
/// Wraps `SMAppService.mainApp` — the modern (macOS 13+) login-item
/// API — so the app registers *itself* as a login item the user
/// toggles in System Settings ▸ General ▸ Login Items, rather than
/// hand-writing a `~/Library/LaunchAgents` plist and shelling out
/// to `launchctl` (the `ServiceManager` path, which stays for its
/// own separate crash-supervision purpose).
///
/// Not the *only* thing that can auto-start the app: the advanced
/// `kiwidesk service` LaunchAgent sets `RunAtLoad`, so it also
/// launches at login, independently of and invisibly to this
/// toggle. The two can both be active (the #196 instance lock
/// dedupes them into one process); this manager owns only the
/// login-item half.
///
/// The GUI toggle is **read-through**: it never caches a bool, it
/// reads `current` (which reflects `SMAppService`'s live status),
/// so a change made in System Settings ▸ Login Items directly is
/// seen on the next poll with no second source of truth.
///
/// Core returns *structure* (`LoginItemState`), never a rendered
/// sentence — the GUI narrates the state at its own boundary (#96).
public enum LoginItemManager {
    /// The live registration state, mapped from the OS.
    ///
    /// `.notFound` is the state macOS reports for `mainApp` *before*
    /// the first registration (verified on 26.x), so it normally
    /// means "registerable, just not on yet" — `state(from:)` folds
    /// it to `.notRegistered`. The one exception is a location where
    /// registration genuinely cannot succeed — a bare non-bundled
    /// binary (device-QA `.build` run) or a Gatekeeper-translocated
    /// download — and there `.notFound` is terminal, so it surfaces
    /// as `.unavailable` (fix: move the app to Applications).
    public static var current: LoginItemState {
        // Location first, unconditionally: a copy at a path that
        // can't be a stable login item (a bare binary, or a
        // Gatekeeper-translocated read-only download) is
        // `.unavailable` whatever `SMAppService` reports — even if
        // a prior install left a stale registration. Only a
        // registerable location consults the live status.
        if let reason = unavailableReason(for: Bundle.main.bundleURL) {
            return .unavailable(reason)
        }
        return state(from: SMAppService.mainApp.status)
    }

    /// Why the bundle at `url` cannot register, or `nil` when it
    /// can. A bare binary launched directly (its bundle URL is the
    /// containing dir, not an `.app`) is `.notBundled`; a
    /// Gatekeeper-translocated `.app` at a read-only randomized path
    /// is `.translocated`; a normal `.app` returns `nil`, so its
    /// `.notFound` is read as the ordinary pre-registration state.
    /// Pure over its argument so all three cases are unit-testable
    /// without touching the real bundle.
    static func unavailableReason(
        for url: URL
    ) -> LoginItemUnavailable? {
        guard url.pathExtension == "app" else { return .notBundled }
        if url.path.contains("/AppTranslocation/") {
            return .translocated
        }
        return nil
    }

    /// Registers or unregisters the app as a login item and returns
    /// the resulting state, so a read-through control can refresh
    /// from one call. A failure (e.g. run as a bare binary rather
    /// than a bundled `.app`, where `SMAppService` has nothing to
    /// register) is logged and folded into the returned state — the
    /// toggle then reflects OS truth rather than the attempted flip.
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

    /// Opens System Settings ▸ General ▸ Login Items — the one
    /// action that resolves a `.requiresApproval` state.
    public static func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Pure mapping from the OS status to our model, kept separate
    /// so it is unit-testable without touching the real
    /// registration. `.notFound` folds to `.notRegistered` — it is
    /// the pre-registration state for `mainApp`, so a registerable
    /// app should offer to turn it on, not grey out (the terminal
    /// `.notFound` is caught by the location check in `current`,
    /// which is the only path that produces `.unavailable`). A
    /// genuinely unknown future status also folds to
    /// `.notRegistered`: offer to enable rather than grey with a
    /// location caption that would not fit — a failed `register()`
    /// then logs and re-reads, flipping the switch back cleanly.
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

/// The four states the "Open at Login" control can be in — the
/// structure Core hands the GUI, which renders the sentence.
public enum LoginItemState: Equatable, Sendable {
    /// Not a login item; the toggle reads off.
    case notRegistered
    /// A login item and active; the toggle reads on.
    case enabled
    /// The user asked for it, but macOS needs them to confirm it in
    /// System Settings ▸ Login Items. The toggle reads on (it
    /// reflects intent) with a status line + a jump button.
    case requiresApproval
    /// Registration cannot succeed from where the app is running,
    /// so the toggle greys out (grey, don't hide, #171). The
    /// associated reason picks the caption — the two causes need
    /// different fixes.
    case unavailable(LoginItemUnavailable)

    /// Whether the switch shows as on. `.requiresApproval` counts as
    /// on: the user said yes, macOS just hasn't confirmed.
    public var isOn: Bool {
        self == .enabled || self == .requiresApproval
    }

    /// The reason the running copy can't register, or `nil` when it
    /// can. Lets `AutoStartManager` fold the unavailability out of
    /// the state without re-matching the enum case.
    public var unavailableReason: LoginItemUnavailable? {
        if case .unavailable(let reason) = self { return reason }
        return nil
    }
}

/// Why `SMAppService` can't register the running copy — each maps to
/// a different caption at the GUI boundary (#96), because the fix
/// differs.
public enum LoginItemUnavailable: Equatable, Sendable {
    /// A bare executable with no `.app` wrapper — the device-QA
    /// `.build/release` path. Fix: run the packaged app.
    case notBundled
    /// A Gatekeeper-translocated read-only copy (a still-quarantined
    /// download run in place). Fix: move it to Applications.
    case translocated
}
