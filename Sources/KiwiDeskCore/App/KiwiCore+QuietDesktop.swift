import Foundation

/// Where a quiet open sends its app's windows (#3152, #3153): one
/// place, so a window is never both filed by the fold and moved.
enum QuietPlace: Equatable {
    case here
    case space(SpaceID)
    case desktop(QuietDesktop)
}

/// The Desktop an `open_in_background` named (#3153): its native id,
/// resolved at the call so a renumbering since moves no window
/// elsewhere, and the KiwiDesk Space it joins there.
struct QuietDesktop: Equatable {
    let id: SkyLight.SpaceID
    let space: SpaceID?
}

extension LaunchFollowIntent {
    /// The Space a quiet open files `bundleID`'s windows into.
    func quietSpace(_ bundleID: String, at now: Date) -> SpaceID? {
        guard opensQuietly(bundleID, at: now),
            case .space(let space)? = quietApps[bundleID]?.place
        else { return nil }
        return space
    }

    /// The Desktop a quiet open sends `bundleID`'s windows to.
    func quietDesktop(_ bundleID: String, at now: Date) -> QuietDesktop? {
        guard opensQuietly(bundleID, at: now),
            case .desktop(let desktop)? = quietApps[bundleID]?.place
        else { return nil }
        return desktop
    }
}

/// `open_in_background`'s Desktop (#3153 ▸ Ruling): each window the
/// app CREATES while its quiet mark stands is sent on through
/// `move_to_desktop`'s own body, in place of the arrival retile. A
/// reveal or a re-track is no open, a Desktop shown by now needs no
/// move, and a pocket or full-screen window is not sent, so the
/// send never meets the verb's focus or refusal cues; a refusal
/// left for the window is logged and the arrival retile runs.
extension KiwiCore {
    /// Sends `window` on; true where it departed.
    func moveQuietArrival(
        _ window: ManagedWindow,
        provenance: ArrivalProvenance
    ) -> Bool {
        guard
            let desktop = launchFollow.quietDesktop(
                window.appRef.listKey,
                at: wallClock()
            ),
            state.pocketPhase(of: window.id) == nil,
            !window.isFullscreen
        else { return false }
        // A create landing after its arrival is not waited for: a
        // background open's window was adopted on sight (#3153).
        guard provenance.isNew == true else {
            onLog("open_in_background: w\(window.id.raw) stays — not new")
            return false
        }
        // The verb re-reads the topology below; both reads run in
        // this one main-actor turn, so a switch cannot land between.
        let snapshot = desktopMemory.readDesktops()
        guard let number = snapshot.number(of: desktop.id),
            snapshot.currentSpaces.values.contains(desktop.id) == false
        else {
            onLog(
                "open_in_background: w\(window.id.raw) stays — its "
                    + "Desktop is gone or showing"
            )
            return false
        }
        let answer = moveToDesktop(
            "move_to_desktop",
            [
                .number(Double(number)),
                desktop.space.map { .string($0.raw) } ?? .null,
                .number(Double(window.id.raw)),
            ],
            follow: false
        )
        if let error = answer.error {
            onLog(
                "open_in_background: w\(window.id.raw) stays — move "
                    + "to Desktop \(number) refused: \(error)"
            )
            return false
        }
        onLog(
            "open_in_background: w\(window.id.raw) sent to Desktop "
                + "\(number)"
        )
        return true
    }
}
