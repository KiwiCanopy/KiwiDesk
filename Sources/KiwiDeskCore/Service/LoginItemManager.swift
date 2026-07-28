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
        let status = SMAppService.mainApp.status
        let registerable = isRegisterable(
            bundleURL: Bundle.main.bundleURL
        )
        if status == .notFound, !registerable {
            return .unavailable
        }
        return state(from: status)
    }

    /// Whether a bundle at `url` is somewhere `SMAppService` can
    /// register it: a real `.app` macOS has not translocated to a
    /// read-only randomized path. A bare binary launched directly
    /// (its bundle URL is the containing dir, not an `.app`) or a
    /// translocated copy cannot register — the terminal `.notFound`
    /// that greys the control, as opposed to the ordinary
    /// pre-registration one. Pure over its argument so all three
    /// cases are unit-testable without touching the real bundle.
    static func isRegisterable(bundleURL url: URL) -> Bool {
        guard url.pathExtension == "app" else { return false }
        return !url.path.contains("/AppTranslocation/")
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

    /// Pure mapping from the OS status to our four-case model, kept
    /// separate so it is unit-testable without touching the real
    /// registration. `.notFound` folds to `.notRegistered` — it is
    /// the pre-registration state for `mainApp`, so a registerable
    /// app should offer to turn it on, not grey out (the terminal
    /// `.notFound` is caught by the location check in `current`).
    /// A genuinely unknown future case folds to `.unavailable`:
    /// grey out rather than lie about an on/off it cannot honor.
    static func state(from status: SMAppService.Status) -> LoginItemState {
        switch status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notRegistered
        @unknown default: return .unavailable
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
    /// Registration cannot succeed from where the app is running —
    /// a Gatekeeper-translocated download or a bare non-bundled
    /// binary — so the toggle greys out (grey, don't hide, #171)
    /// and the caption points at the fix: move to Applications.
    case unavailable

    /// Whether the switch shows as on. `.requiresApproval` counts as
    /// on: the user said yes, macOS just hasn't confirmed.
    public var isOn: Bool {
        self == .enabled || self == .requiresApproval
    }
}
