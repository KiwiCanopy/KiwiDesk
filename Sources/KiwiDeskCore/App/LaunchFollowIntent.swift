import Foundation

/// The follow a USER activation owes its app's next window when
/// an app rule files it in another Space (#1599), paid at that
/// window's ARRIVAL like `FollowFocusIntent`'s debts. Keyed by
/// the app, not the window: at the activation the window does
/// not exist yet, which is why this is not a third instance of
/// that type (#890's weighing).
///
/// Minted only for an activation a press caused
/// (`KiwiCore.noteAppActivation`), so a background spawn, the
/// boot scan and a login restore — none of which is one — owe
/// nothing by construction. One pending, paid once; the next
/// activation replaces it and a Desktop switch retires it.
@MainActor
final class LaunchFollowIntent {
    /// How long after its activation a launch's window may still
    /// claim the follow: `FollowFocusIntent.drainWindow` for the
    /// launch itself, plus one adoption-heal period, because a
    /// fresh launch's first window is routinely adopted by the
    /// heal rather than its create notification (#675) — measured
    /// 0.04–6.3 s after the activation on device (#1599).
    static let drainWindow: TimeInterval =
        FollowFocusIntent.drainWindow
        + TimeInterval(KiwiCore.adoptionHealDefault.components.seconds)

    /// Longest gap between a click or key-down and the activation
    /// it caused: a Dock click measured 0.29 s and a Spotlight
    /// Return 0.35 s, a login restore's activation 15 s after the
    /// password (#1599).
    static let pressGrace: TimeInterval = 1

    /// An activation this soon after a native Desktop switch is
    /// the switch's own, not a launch: measured 0.3–0.9 s after
    /// it, so twice the switch's settle clears the tail (#1599).
    static let desktopSwitchGrace: TimeInterval =
        2 * DesktopSwitch.settle

    /// Seconds since the last left click or key-down. nil until
    /// `start()` wires it, so a unit test mints no follow unless
    /// it injects one (`LaunchFollowSeamTests` pins the arming).
    var pressAge: (@MainActor () -> TimeInterval?)?

    private var pending: (pid: pid_t, at: Date)?

    /// Records that `pid`'s next rule-placed window is owed a
    /// follow; replaces any earlier debt.
    func record(_ pid: pid_t, at now: Date = Date()) {
        pending = (pid, now)
    }

    /// Claims the follow for a window of `pid`; true once, within
    /// the bound. Any live debt for another app is left standing.
    func claim(_ pid: pid_t, at now: Date = Date()) -> Bool {
        guard let owed = owed(at: now), owed == pid else {
            return false
        }
        pending = nil
        return true
    }

    /// The owing app, nil once expired (which drops it) or absent.
    func owed(at now: Date = Date()) -> pid_t? {
        guard let pending else { return nil }
        guard now.timeIntervalSince(pending.at) < Self.drainWindow
        else {
            self.pending = nil
            return nil
        }
        return pending.pid
    }

    /// Retires the debt unpaid.
    func forget() {
        pending = nil
    }
}
