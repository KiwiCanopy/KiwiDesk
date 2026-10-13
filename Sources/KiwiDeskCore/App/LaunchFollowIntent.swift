import Foundation

/// The follow an OPEN — a launch, a reopen, an un-minimize — owes
/// its app's next window when an app rule files it in another
/// Space (#1599), paid at that window's
/// ARRIVAL like `FollowFocusIntent`'s debts. Keyed by the app's
/// bundle id, not a window or a pid: at the launch the window
/// does not exist, and Open or Focus owes it before the process
/// does — which is why this is not a third instance of that type
/// (#890's weighing).
///
/// Owed through `KiwiCore.oweLaunchFollow` alone: by Open or
/// Focus, by `new_window` (#1518), and by an activation that
/// `noteAppActivation` judges a launch. One pending, paid once;
/// another app's activation, a Desktop switch and a refused New
/// Window retire it.
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
        + TimeInterval(
            KiwiCore.adoptionHealDefault
                / Duration.milliseconds(1)
        ) / 1_000

    /// Longest gap between a click or key-down and the activation
    /// it caused: a Dock click measured 0.29 s and a Spotlight
    /// Return 0.35 s, a login restore's activation 15 s after the
    /// password (#1599). It bounds #2187's app-act motion too.
    static let pressGrace: TimeInterval = 1

    /// Longest gap between a process starting and its activation
    /// for that activation to be its LAUNCH: measured at most
    /// 0.3 s; the rest is headroom for a slow cold start. An
    /// older process opens only when it shows no window (#1599).
    static let launchGrace: TimeInterval = 5

    /// An activation this soon after a native Desktop switch is
    /// the switch's own, not a launch: measured 0.3–0.9 s after
    /// it, so twice the switch's settle clears the tail (#1599).
    static let desktopSwitchGrace: TimeInterval =
        2 * DesktopSwitch.settle

    /// Seconds since the last left click or key-down. nil until
    /// `start()` wires it, so a unit test mints no follow unless
    /// it injects one (`LaunchFollowSeamTests` pins the arming).
    /// Read through `recentPress()`, by #2187's motion as well.
    var pressAge: (@MainActor () -> TimeInterval?)?

    /// The last press's age while inside `pressGrace`, else nil.
    func recentPress() -> TimeInterval? {
        guard let press = pressAge?(), press <= Self.pressGrace
        else { return nil }
        return press
    }

    /// When `start()` armed the press read. A press older than it
    /// predates KiwiDesk — the login password — and never opened
    /// a launch (#2201). nil until wired, like `pressAge`.
    var watchingSince: Date?

    /// The last press's age when it came at most `pressGrace`
    /// BEFORE a process started at `launchedAt`, and while
    /// KiwiDesk watched: that press launched it, however late a
    /// cold start activates — 1.4–7.8 s measured (#2201).
    func pressBefore(launch launchedAt: Date, now: Date) -> TimeInterval? {
        guard let watchingSince, let press = pressAge?() else {
            return nil
        }
        let pressedAt = now.addingTimeInterval(-press)
        let lead = launchedAt.timeIntervalSince(pressedAt)
        guard pressedAt >= watchingSince, lead >= 0,
            lead <= Self.pressGrace
        else { return nil }
        return press
    }

    private var pending: (bundleID: String, at: Date)?

    /// A rule-placed window that arrived with NO debt standing — a
    /// reopen or an un-minimize can show the window before macOS
    /// reports its app active (device, #1599). One slot: the
    /// activation that follows it claims it or it is replaced.
    struct Placement {
        let window: WindowID
        let bundleID: String
        let space: SpaceID
        let at: Date
    }
    private(set) var placement: Placement?

    /// Remembers `placement` for an activation still to come.
    func notePlacement(_ placement: Placement) {
        self.placement = placement
    }

    /// Takes the placement for `bundleID` if it arrived no earlier
    /// than `since` — after the press that caused the activation.
    func takePlacement(_ bundleID: String, since: Date) -> Placement? {
        guard let placement, placement.bundleID == bundleID,
            placement.at >= since
        else { return nil }
        self.placement = nil
        return placement
    }

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

    /// Retires `bundleID`'s debt alone, leaving any placement: a
    /// refused New Window opened nothing, and a placement waits on
    /// its own app's activation (#1518).
    func forget(pending bundleID: String) {
        if pending?.bundleID == bundleID { pending = nil }
    }

    /// Retires the debt unpaid, and any placement waiting for one
    /// except `keeping`'s — the app whose activation is judging it.
    func forget(keeping bundleID: String? = nil) {
        pending = nil
        if placement?.bundleID != bundleID || bundleID == nil {
            placement = nil
        }
    }
}
