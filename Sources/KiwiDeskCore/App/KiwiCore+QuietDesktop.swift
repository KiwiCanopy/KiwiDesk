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
/// `move_to_desktop`'s own body, at the arrival in place of its
/// retile, or where the create trails the arrival, once the
/// provenance door settles it (#2630). A reveal or a re-track is no
/// open, a Desktop shown by now needs no move, and a pocket or
/// full-screen window is not sent, so the send never meets the
/// verb's focus or refusal cues; a refusal left for the window is
/// logged and the arrival retile runs.
extension KiwiCore {
    /// The arrival's door: sends `window` on where it reads as new,
    /// and leaves one awaiting its create to `settleArrival`. True
    /// where it departed.
    func moveQuietArrival(
        _ window: ManagedWindow,
        provenance: ArrivalProvenance
    ) -> Bool {
        guard let app = window.appRef.listKey,
            launchFollow.quietDesktop(
                app,
                at: wallClock()
            ) != nil
        else { return false }
        switch provenance.isNew {
        case true?:
            return sendQuietArrival(window.id)
        case nil:
            onLog(
                "open_in_background: w\(window.id.raw) waits for its "
                    + "create"
            )
            return false
        case false?:
            return false
        }
    }

    /// The held arrival's settle (#2630): a landed create sends it,
    /// an expired one leaves it where it opened, said so.
    func settleQuietArrival(_ id: WindowID, created: Bool) {
        guard created else {
            if let app = state.windows[id]?.appRef.listKey,
                launchFollow.quietDesktop(app, at: wallClock()) != nil
            {
                onLog(
                    "open_in_background: w\(id.raw) stays — no create "
                        + "within \(LaunchFollowIntent.lateCreateBound)s"
                )
            }
            return
        }
        _ = sendQuietArrival(id)
    }

    /// The one send, from either door; true where it departed.
    func sendQuietArrival(_ id: WindowID) -> Bool {
        guard let window = state.windows[id],
            let app = window.appRef.listKey,
            let desktop = launchFollow.quietDesktop(
                app,
                at: wallClock()
            ),
            state.pocketPhase(of: id) == nil,
            !window.isFullscreen
        else { return false }
        // The verb re-reads the topology below; both reads run in
        // this one main-actor turn, so a switch cannot land between.
        let snapshot = desktopMemory.readDesktops()
        guard let number = snapshot.number(of: desktop.id),
            snapshot.currentSpaces.values.contains(desktop.id) == false
        else {
            onLog(
                "open_in_background: w\(id.raw) stays — its Desktop "
                    + "is gone or showing"
            )
            return false
        }
        let answer = moveToDesktop(
            "move_to_desktop",
            [
                .number(Double(number)),
                desktop.space.map { .string($0.raw) } ?? .null,
                .number(Double(id.raw)),
            ],
            follow: false
        )
        if let error = answer.error {
            onLog(
                "open_in_background: w\(id.raw) stays — move to "
                    + "Desktop \(number) refused: \(error)"
            )
            return false
        }
        onLog("open_in_background: w\(id.raw) sent to Desktop \(number)")
        return true
    }
}
