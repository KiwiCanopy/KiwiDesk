import Foundation

/// The Desktop switch cue's two doors (#2142): owed by
/// `switchDesktop` alone, paid by `handleDesktopChange` alone —
/// a gesture or Mission Control switch owes nothing, since macOS
/// animates those itself.
extension KiwiCore {
    /// The GUI's hook: handed every cue the switch handler pays.
    public var onDesktopCue: @MainActor (DesktopSwitchCue) -> Void {
        get { desktopCue.onCue }
        set { desktopCue.onCue = newValue }
    }

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
    /// (#888). A debt whose screen does not show the target yet
    /// waits for the next notification, inside the bound.
    func payDesktopCue(
        in snapshot: DesktopSnapshot,
        loadedProfile: String?
    ) {
        guard let owed = desktopCue.owed else { return }
        let verdict = DesktopCueLedger.verdict(
            for: owed,
            in: snapshot,
            display: cueDisplay(owed.displayUUID, in: snapshot),
            loadedProfile: loadedProfile,
            now: wallClock()
        )
        guard case .settled(let cue) = verdict else { return }
        desktopCue.owed = nil
        // The shelf's stand-down, the one home of it (#1787): a
        // full-screen Desktop earned no cue above, and a show in
        // front of this screen keeps it clear.
        guard let cue, appWide.desktopCue,
            !showsPresentation(on: cue.display)
        else { return }
        desktopCue.onCue(cue)
    }

    /// The screen a switched Desktop lives on. With "Displays have
    /// separate Spaces" off every Desktop is shared and its
    /// managed-display identifier names no screen, so the cue
    /// draws on the main one.
    func cueDisplay(
        _ uuid: String,
        in snapshot: DesktopSnapshot
    ) -> DisplayID? {
        if let display = display(forUUID: uuid) { return display }
        let shared = Set(snapshot.spaces.map(\.displayUUID)).count == 1
        return shared ? display(forUUID: snapshot.mainUUID) : nil
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
