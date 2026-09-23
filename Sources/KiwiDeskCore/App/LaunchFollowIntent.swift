import Foundation

/// The follow a LAUNCH owes its app's next window when an app
/// rule files it in another Space (#1599), paid at that window's
/// ARRIVAL like `FollowFocusIntent`'s debts. Keyed by the app's
/// bundle id, not a window or a pid: at the launch the window
/// does not exist, and Open or Focus owes it before the process
/// does — which is why this is not a third instance of that type
/// (#890's weighing).
///
/// Owed through `KiwiCore.oweLaunchFollow` alone: by Open or
/// Focus, and by an activation that `noteAppActivation` judges a
/// launch. One pending, paid once; another app's activation and
/// a Desktop switch retire it.
@MainActor
final class LaunchFollowIntent {
    /// How long after the launch its window may still claim the
    /// follow: `FollowFocusIntent.drainWindow` for the launch
    /// itself, plus one adoption-heal period, because a fresh
    /// launch's first window is routinely adopted by the heal
    /// rather than its create notification (#675) — measured
    /// 0.04–6.3 s after the activation on device (#1599).
    static let drainWindow: TimeInterval =
        FollowFocusIntent.drainWindow
        + KiwiCore.adoptionHealDefault.seconds

    /// Longest gap between a click or key-down and the activation
    /// it caused: a Dock click measured 0.29 s and a Spotlight
    /// Return 0.35 s, a login restore's activation 15 s after the
    /// password (#1599).
    static let pressGrace: TimeInterval = 1

    /// Longest gap between a process starting and its activation
    /// for that activation to be its LAUNCH: measured at most
    /// 0.3 s; the rest is headroom for a slow cold start. A
    /// running app coming forward — a switch, a self-activation,
    /// an un-minimize — is older (#1599).
    static let launchGrace: TimeInterval = FollowFocusIntent.drainWindow

    /// An activation this soon after a native Desktop switch is
    /// the switch's own, not a launch: measured 0.3–0.9 s after
    /// it, so twice the switch's settle clears the tail (#1599).
    static let desktopSwitchGrace: TimeInterval =
        2 * DesktopSwitch.settle

    /// Seconds since the last left click or key-down. nil until
    /// `start()` wires it, so a unit test mints no follow unless
    /// it injects one (`LaunchFollowSeamTests` pins the arming).
    var pressAge: (@MainActor () -> TimeInterval?)?

    private var pending: (bundleID: String, at: Date)?

    /// Records that `bundleID`'s next rule-placed window is owed a
    /// follow; replaces any earlier debt.
    func record(_ bundleID: String, at now: Date) {
        pending = (bundleID, now)
    }

    /// Claims the follow for a window of `bundleID`; true once,
    /// within the bound. Another app's live debt is left standing.
    func claim(_ bundleID: String, at now: Date) -> Bool {
        guard let owed = owed(at: now), owed == bundleID else {
            return false
        }
        pending = nil
        return true
    }

    /// The owing app, nil once expired (which drops it) or absent.
    func owed(at now: Date = Date()) -> String? {
        guard let pending else { return nil }
        guard now.timeIntervalSince(pending.at) < Self.drainWindow
        else {
            self.pending = nil
            return nil
        }
        return pending.bundleID
    }

    /// Retires the debt unpaid.
    func forget() {
        pending = nil
    }
}

extension Duration {
    /// The duration in seconds, fraction included.
    var seconds: TimeInterval {
        let parts = components
        return TimeInterval(parts.seconds)
            + TimeInterval(parts.attoseconds) / 1e18
    }
}
