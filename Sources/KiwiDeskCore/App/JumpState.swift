import Foundation

/// Jump to window's state on the core (#1875): the focus a Move
/// here owes the window it moved, and the WindowServer reading
/// the list drops a stale minimize record by.
///
/// The focus is owed only where a move was DISPATCHED for that
/// window — a hop the bridge accepted, an un-minimize — so its
/// arrival is certain; it is paid at that arrival with a plain
/// focus, never a Space switch, and only while the Space it was
/// owed for is still the active one. A Move here that lands
/// elsewhere (an un-minimized window taking its app rule) is
/// filed into that Space at the payment, so nothing is filed
/// ahead of an arrival that may never come, and whatever stands
/// the focus down since (#2883). Not a
/// `FollowFocusIntent`: that debt pays as a switch and holds the
/// Desktop return down (#1207) while it stands, and this one
/// must do neither. A window that never arrives needs no retire:
/// the debt is judged by its age when it is taken.
@MainActor
final class JumpState {
    /// One owed focus: the window, the Space it was moved into,
    /// and when — on the wall clock for the press check and the
    /// bound, on the continuous clock for the commanded focus.
    struct Owed: Equatable {
        var window: WindowID
        let space: SpaceID
        let at: Date
        let commandedAt: ContinuousClock.Instant
        /// Move here: file the window into `space` if it lands
        /// anywhere else; a Jump's focus only stands down there.
        let relocates: Bool
        /// Move here's hop from another Desktop (#2770).
        let hopped: Bool
    }

    private(set) var owed: Owed?

    /// A hidden app's Move here (#1513): its windows are not
    /// tracked until the unhide brings them back, so the debt is
    /// the app's, paid by its first honored focus report.
    struct OwedApp: Equatable {
        let pid: pid_t
        let space: SpaceID
        let at: Date
        let commandedAt: ContinuousClock.Instant
        /// `move_here`'s title text: the window moves only if its
        /// title contains it.
        let matching: String?
    }

    private(set) var owedApp: OwedApp?

    func oweApp(
        _ pid: pid_t,
        in space: SpaceID,
        at now: Date,
        matching text: String?
    ) {
        owedApp = OwedApp(
            pid: pid,
            space: space,
            at: now,
            commandedAt: .now,
            matching: text
        )
    }

    /// Ends the app's debt at its first honored report, paid or not.
    func takeApp(_ pid: pid_t) -> OwedApp? {
        guard let owedApp, owedApp.pid == pid else { return nil }
        self.owedApp = nil
        return owedApp
    }

    /// Every layer-0 window id on any Desktop, nil where no
    /// reading answers (the list then keeps every record). Pinned
    /// by `makeTestCore`.
    var knownWindows: () -> Set<WindowID>? = {
        JumpState.known(AXHelper.allNormalWindowOwners())
    }

    /// The reading's ids, nil for an empty one: a failed read
    /// answers empty, and "no window at all" keeps every record.
    nonisolated static func known(
        _ owners: [WindowID: pid_t]
    ) -> Set<WindowID>? {
        owners.isEmpty ? nil : Set(owners.keys)
    }

    func owe(
        _ window: WindowID,
        in space: SpaceID,
        at now: Date,
        relocates: Bool,
        hopped: Bool = false
    ) {
        owed = Owed(
            window: window,
            space: space,
            at: now,
            commandedAt: .now,
            relocates: relocates,
            hopped: hopped
        )
    }

    /// Ends the debt for `window`, paid or not — its arrival is
    /// the one moment it can be paid.
    func take(arrived window: WindowID) -> Owed? {
        guard let owed, owed.window == window else { return nil }
        self.owed = nil
        return owed
    }

    /// A window that can never arrive retires its debt.
    func retire(_ id: WindowID) {
        if owed?.window == id { owed = nil }
    }

    /// Follows a native-tab re-key (#308).
    func rekey(old: WindowID, new: WindowID) {
        if owed?.window == old { owed?.window = new }
    }
}

extension KiwiCore {
    /// Pays Move here's two debts at the window's arrival (#1875),
    /// in the `.windowCreated` arm beside the follow's payment.
    /// The filing is the move the user asked for and is paid
    /// whatever was pressed, focused or switched since (#2883);
    /// only the focus stands down: off the Space it was owed for,
    /// or after a press or a commanded focus since. Past the
    /// follow's bound nothing is paid.
    func payMoveHereFocus(arrived window: WindowID) {
        guard let owed = jump.take(arrived: window) else { return }
        let age = wallClock().timeIntervalSince(owed.at)
        guard age < FollowFocusIntent.drainWindow else {
            onLog(
                "move here: w\(window.raw) arrived past its bound — "
                    + "nothing filed, focus stood down"
            )
            return
        }
        fileMoveHere(window, owed)
        let pressed = launchFollow.pressed(within: age)
        let commanded =
            eventLoop.lastCommandedFocus.map { $0 > owed.commandedAt }
            ?? false
        guard state.workspaces.activeSpace == owed.space,
            state.workspaces.space(of: window) == owed.space,
            !pressed, !commanded
        else {
            onLog("move here: w\(window.raw) arrived — focus stood down")
            return
        }
        focusWindow(window, refocusRetile: false, warp: true)
        onLog("move here: focus handed to w\(window.raw)")
    }

    /// Move here's filing: a landing elsewhere files into the owed
    /// Space (a hidden one parks it) past the sticky gate, and a
    /// hopped float that landed there is placed on its new screen.
    /// Both need the Space still to exist.
    private func fileMoveHere(_ window: WindowID, _ owed: JumpState.Owed) {
        guard let landed = state.workspaces.space(of: window),
            state.workspaces[owed.space] != nil
        else { return }
        if landed != owed.space {
            guard owed.relocates,
                stickyMoveBlock(window, to: owed.space) == nil
            else { return }
            fileMembership(window, into: owed.space, from: landed)
        } else if owed.hopped, reanchorFloat(window, to: owed.space) {
            // A hopped float may report its pre-move frame (#2770).
            onLog("move here: w\(window.raw) placed on its new screen")
        }
    }
}
