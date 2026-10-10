import Foundation

/// The Desktop switch cue's two doors (#2142): owed by
/// `switchDesktop` alone, paid by `handleDesktopChange` alone —
/// a gesture or Mission Control switch owes nothing, since macOS
/// animates those itself.
extension KiwiCore {
    /// Called once the bridge accepted the set: the instant switch
    /// has no motion, so the plate is its cue.
    func oweDesktopCue(_ target: DesktopTarget) {
        desktopCue.owed = DesktopCueLedger.Owed(
            displayUUID: target.displayIdentifier,
            space: target.space,
            at: wallClock()
        )
    }

    /// Called at the switch handler's tail, from its one snapshot
    /// (#888). An owed cue whose screen does not show the target
    /// yet waits for the next notification, inside the bound.
    func payDesktopCue(
        in snapshot: DesktopSnapshot,
        loadedProfile: String?
    ) {
        guard let owed = desktopCue.owed else { return }
        let now = wallClock()
        if now.timeIntervalSince(owed.at) > DesktopCueLedger.bound {
            desktopCue.owed = nil
            return
        }
        guard
            let cue = DesktopCueLedger.cue(
                for: owed,
                in: snapshot,
                display: display(forUUID: owed.displayUUID),
                loadedProfile: loadedProfile,
                now: now
            )
        else { return }
        desktopCue.owed = nil
        guard appWide.desktopCue else { return }
        desktopCue.onCue(cue)
    }

    /// `KiwiDesk.set_desktop_cue(bool)` (#2142): turns the plate
    /// on or off. App-wide (#1741) and session-only, as every
    /// app-wide verb; no retile.
    func setDesktopCue(_ args: [JSONValue]) -> CommandResponse {
        guard let on = args.first?.boolValue else {
            return .fail("expected a boolean")
        }
        setAppWide(persisting: false) { $0.desktopCue = on }
        return .ok()
    }
}
