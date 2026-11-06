import Foundation

/// A Desktop move naming a window on a hidden Desktop (#3034). The
/// window is in the away ledger, never in state, so no departure
/// follows the move: its filing is written at once, and the arrival's
/// ordinary rule pays it.
extension KiwiCore {
    /// Moves `away` to `target`, and with `follow` switches there.
    func moveAwayToDesktop(
        _ away: AwayWindow,
        to target: DesktopTarget,
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        if let refusal = awayMoveRefusal(away, to: target, follow: follow) {
            return refusal
        }
        let explicit: SpaceID?
        switch resolveSpaceTarget(args, for: target, moving: away.id) {
        case .refused(let response):
            return response
        case .none:
            explicit = nil
        case .space(let space, _):
            guard !awayIsSticky(away) else {
                return .fail("a sticky window keeps its Space")
            }
            explicit = space
        }
        guard WMBridge.moveWindows([away.id], to: target.space) else {
            return .fail("the Desktop bridge is unavailable on this macOS")
        }
        if let explicit { state.workspaces.ensureSpace(explicit) }
        // An unfiled window takes the Space its screen shows, or the
        // fold would grant it a new window's focus.
        state.fileAwayMove(
            away.id,
            named: explicit,
            home: moveHereSpace(on: screenHolding(away.id))
        )
        onLog(
            "move_to_desktop: away w\(away.id.raw) filed under space "
                + "\(state.rememberedSpace(of: away.id)?.raw ?? "none")"
        )
        guard follow else {
            armMoveReap(pid: away.pid)
            return .ok()
        }
        let outcome = switchDesktop(
            to: target,
            verb: "move_to_desktop_and_follow"
        )
        switch outcome {
        case .switched:
            followFocus.record(away.id)
            onLog(
                "follow: owing focus to w\(away.id.raw) "
                    + "when its Desktop reveals it"
            )
        case .alreadyShown:
            // No reveal: the Space switches now and the reap's
            // arrival takes a plain focus, as Move here's does.
            armMoveReap(pid: away.pid)
            if let space = shownFollowSpace(of: away.id, on: target) {
                enterMoveHereSpace(space)
                jump.owe(
                    away.id,
                    in: space,
                    at: wallClock(),
                    relocates: true,
                    hopped: true
                )
            }
        case .refused:
            armMoveReap(pid: away.pid)
        }
        return outcome.response
    }

    /// What refuses an away window before anything moves. A follow
    /// ends with focus on the window, which a minimized or hidden one
    /// cannot take, so it never switches for one.
    private func awayMoveRefusal(
        _ away: AwayWindow,
        to target: DesktopTarget,
        follow: Bool
    ) -> CommandResponse? {
        switch state.pocketPhase(of: away.id) {
        case .pocketed:
            return .fail(Self.pocketedMoveRefusal)
        case .out:
            return .fail(Self.outPocketMoveRefusal)
        case nil:
            break
        }
        if isFullScreenHost(away.nativeSpace, in: target.spaces) {
            return .fail("a full-screen window cannot change Desktop")
        }
        if follow, !away.isUp {
            return .fail("Can't follow a minimized or hidden window.")
        }
        return nil
    }

    /// Whether `away` left with a sticky scope, restored at its
    /// arrival (#414): a named Space is a membership write the
    /// sticky gate refuses, and that gate reads tracked windows.
    private func awayIsSticky(_ away: AwayWindow) -> Bool {
        let window = ManagedWindow(
            id: away.id,
            pid: away.pid,
            appName: away.appName,
            appBundleID: away.appBundleID,
            title: away.title
        )
        return state.remembersSticky(window)
    }

    /// The Space a follow onto a shown Desktop lands in: its filing,
    /// or where a shown screen other than its Space's re-homes it.
    private func shownFollowSpace(
        of window: WindowID,
        on target: DesktopTarget
    ) -> SpaceID? {
        guard let filed = state.rememberedSpace(of: window) else {
            return nil
        }
        guard let screen = display(forUUID: target.displayIdentifier),
            state.workspaces.display(of: filed) != screen
        else { return filed }
        return moveHereSpace(on: screen)
    }
}
