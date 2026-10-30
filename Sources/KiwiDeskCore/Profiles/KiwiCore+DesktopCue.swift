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
        // The shelf's stand-down, the one home of it (#1787, #2348):
        // a full-screen Desktop or a show in front of this screen
        // keeps it clear, as it does the bars and the other cues.
        guard let cue, appWide.desktopCue,
            !shelfStandsDown(on: cue.display)
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
        return sharedDesktopKey(in: snapshot) != nil
            ? display(forUUID: snapshot.mainUUID) : nil
    }

    /// The shared managed-display id every Desktop sits under with
    /// "Displays have separate Spaces" off: the snapshot's sole key,
    /// and one no connected screen answers to (#2770).
    func sharedDesktopKey(in snapshot: DesktopSnapshot) -> String? {
        guard let key = snapshot.soleDisplayKey,
            display(forUUID: key) == nil
        else { return nil }
        return key
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
