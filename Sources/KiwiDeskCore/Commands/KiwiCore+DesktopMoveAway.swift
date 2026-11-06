import Foundation

/// A Desktop move naming a window on a hidden Desktop (#3034). The
/// window is in the away ledger, never in state, so no departure
/// follows the move: a named Space is filed at once through the
/// remembered Space, and the arrival's ordinary rule pays it.
extension KiwiCore {
    /// Moves `away` to `target`, and with `follow` switches there.
    /// A sticky window's gate reads tracked flags, so it does not
    /// apply here; the carry owns such a window's Desktop (#1145).
    func moveAwayToDesktop(
        _ away: AwayWindow,
        to target: DesktopTarget,
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard !awayIsFullScreen(away, in: desktopMemory.readDesktops())
        else { return .fail("a full-screen window cannot change Desktop") }
        let explicit: SpaceID?
        switch resolveSpaceTarget(args, for: target, moving: away.id) {
        case .refused(let response):
            return response
        case .none:
            explicit = nil
        case .space(let space, _):
            explicit = space
        }
        guard WMBridge.moveWindows([away.id], to: target.space) else {
            return .fail("the Desktop bridge is unavailable on this macOS")
        }
        if let explicit {
            state.workspaces.ensureSpace(explicit)
            state.fileAway(away.id, in: explicit)
            onLog(
                "move_to_desktop: away w\(away.id.raw) filed under "
                    + "space \(explicit.raw)"
            )
        }
        armMoveReap(pid: away.pid)
        guard follow else { return .ok() }
        let outcome = switchDesktop(
            to: target,
            verb: "move_to_desktop_and_follow"
        )
        switch outcome {
        case .switched, .alreadyShown:
            // A shown Desktop still owes this window an arrival:
            // the reap adopts it, and the debt is paid there.
            followFocus.record(away.id)
        case .refused:
            break
        }
        return outcome.response
    }
}
