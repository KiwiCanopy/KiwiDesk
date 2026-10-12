import Foundation

/// Jump to window's state on the core (#1875): the focus a Move
/// here owes the window it moved, and the WindowServer reading
/// the list drops a stale minimize record by.
///
/// The focus is owed only where a move was DISPATCHED for that
/// window — a hop the bridge accepted, an un-minimize filed for
/// the active Space — so its arrival is certain; it is paid at
/// that arrival with a plain focus, never a Space switch, and
/// only into the Space it was owed for while that Space is
/// still the active one. Not a `FollowFocusIntent`: that debt
/// pays as a switch and holds the Desktop return down (#1207)
/// while it stands, and this one must do neither.
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
    }

    private(set) var owed: Owed?

    /// Every layer-0 window id on any Desktop, nil where no
    /// reading answers (the list then keeps every record). Pinned
    /// by `makeTestCore`.
    var knownWindows: () -> Set<WindowID>? = {
        Set(AXHelper.allNormalWindowOwners().keys)
    }

    func owe(_ window: WindowID, in space: SpaceID, at now: Date) {
        owed = Owed(
            window: window,
            space: space,
            at: now,
            commandedAt: .now
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
    /// Pays Move here's focus at the window's arrival (#1875), in
    /// the `.windowCreated` arm beside the follow's payment. Stands
    /// down past the follow's bound, outside the Space it was owed
    /// for, or after a press or a commanded focus since.
    func payMoveHereFocus(arrived window: WindowID) {
        guard let owed = jump.take(arrived: window) else { return }
        let now = wallClock()
        let age = now.timeIntervalSince(owed.at)
        let pressed = launchFollow.pressAge?().map { $0 < age } ?? false
        let commanded =
            eventLoop.lastCommandedFocus.map { $0 > owed.commandedAt }
            ?? false
        guard age < FollowFocusIntent.drainWindow,
            state.workspaces.activeSpace == owed.space,
            state.workspaces.space(of: window) == owed.space,
            !pressed, !commanded
        else {
            onLog("move here: w\(window.raw) arrived — focus stood down")
            return
        }
        focusWindow(window, refocusRetile: false, warp: true)
        onLog("move here: focus handed to w\(window.raw)")
    }
}
