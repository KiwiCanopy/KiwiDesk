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
///
/// Its second arm is owed nothing (#2478): a window WindowServer
/// created while KiwiDesk watched (`WindowCreateLedger`) follows
/// when `spawnFollows` says the user or an old process opened it.
/// That arm never writes the debt; its one slot, `spawn`, waits
/// for a create that lands after the window's arrival.
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

    /// Longest gap between a process starting and an activation
    /// within `pressGrace` of a press for it to be the LAUNCH:
    /// measured at most 0.3 s (#1599); a press that came before
    /// the start is `coldStartGrace`'s. An older process opens
    /// only when it shows no window.
    static let launchGrace: TimeInterval = 5

    /// Longest gap between a press-started process and its
    /// activation for that press to stay its cause: twice the
    /// slowest cold start measured, Word's 7.58 s (#2201). Past
    /// it the activation is the app's own.
    static let coldStartGrace: TimeInterval = 15

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

    /// Seconds since KiwiDesk began managing windows
    /// (`boot.began`). A press older than that predates it — the
    /// login password — and opened nothing (#2201). nil until
    /// `start()` wires it, like `pressAge`.
    var watchedFor: (@MainActor () -> TimeInterval?)?

    /// Whether a press came within the last `age` seconds — the
    /// one reading for a ledger asking "pressed since I was
    /// owed", Jump's two stand-downs.
    func pressed(within age: TimeInterval) -> Bool {
        pressAge?().map { $0 < age } ?? false
    }

    /// The last press's age when it came at most `pressGrace`
    /// BEFORE a process that started `startedAgo` seconds ago,
    /// within `coldStartGrace`, while KiwiDesk watched: that
    /// press launched it, however late a cold start activates
    /// (#2201).
    func pressBefore(startedAgo: TimeInterval) -> TimeInterval? {
        guard startedAgo <= Self.coldStartGrace,
            let watched = watchedFor?(), let press = pressAge?(),
            press <= watched
        else { return nil }
        let lead = press - startedAgo
        guard lead >= 0, lead <= Self.pressGrace else { return nil }
        return press
    }

    /// Seconds since the kernel started a process
    /// (`ProcessIdentity.startAge`). nil until `start()` wires it,
    /// so a unit test follows no unowed window unless it injects
    /// one (`LaunchFollowSeamTests` pins the arming).
    var processAge: (@MainActor (pid_t) -> TimeInterval?)?

    /// Whether a new window of `pid`, created while KiwiDesk
    /// watched and owed nothing, follows its rule (#2478 ▸ Ruling
    /// — login restore): a process older than `coldStartGrace`,
    /// or a press within `pressGrace` since KiwiDesk started. An
    /// unreadable age counts as young, so a login restore — no
    /// press near it, the password older than KiwiDesk — stays.
    func spawnFollows(pid: pid_t) -> Bool {
        if let press = recentPress(), let watched = watchedFor?(),
            press <= watched
        {
            return true
        }
        guard let age = processAge?(pid) else { return false }
        return age >= Self.coldStartGrace
    }

    /// Longest gap between a window's arrival and its create for
    /// that create to pay the follow: the create trails the AX
    /// arrival by 8–10 ms on TextEdit's ⌘N (device, 2026-10-22).
    static let lateCreateBound: TimeInterval = 0.5

    /// A window the unowed arm passed in every way but its create,
    /// which had not landed yet. One slot.
    struct Spawn {
        let window: WindowID
        let bundleID: String
        let space: SpaceID
        /// The Space the user was in, which a payment requires
        /// they still are.
        let from: SpaceID?
        let at: Date
    }
    private(set) var spawn: Spawn?

    /// Remembers `spawn` for a create still to come.
    func noteSpawn(_ spawn: Spawn) {
        self.spawn = spawn
    }

    /// Drops the slot: the core stopped.
    func dropSpawn() {
        spawn = nil
    }

    /// Takes the slot for `window` while within `lateCreateBound`.
    func takeSpawn(_ window: WindowID, at now: Date) -> Spawn? {
        guard let spawn, spawn.window == window else { return nil }
        self.spawn = nil
        guard now.timeIntervalSince(spawn.at) < Self.lateCreateBound
        else { return nil }
        return spawn
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

    /// Retires the debt unpaid, and any spawn or placement waiting
    /// on a create or an activation except `keeping`'s — the app
    /// whose activation is judging it.
    func forget(keeping bundleID: String? = nil) {
        pending = nil
        if spawn?.bundleID != bundleID || bundleID == nil {
            spawn = nil
        }
        if placement?.bundleID != bundleID || bundleID == nil {
            placement = nil
        }
    }
}
