import Foundation

/// The Desktop an `open_in_background` named (#3153): its Desktop
/// number, and the KiwiDesk Space there, as `move_to_desktop` takes
/// them.
struct QuietDesktop: Equatable {
    let number: Int
    let space: String?
}

extension LaunchFollowIntent {
    /// The Space a quiet open files `bundleID`'s windows into.
    func quietSpace(_ bundleID: String, at now: Date) -> SpaceID? {
        opensQuietly(bundleID, at: now) ? quietApps[bundleID]?.into : nil
    }

    /// The Desktop a quiet open sends `bundleID`'s windows to (#3153).
    func quietDesktop(_ bundleID: String, at now: Date) -> QuietDesktop? {
        opensQuietly(bundleID, at: now) ? quietApps[bundleID]?.desktop : nil
    }
}

/// `open_in_background`'s Desktop (#3153 ▸ Ruling): each window of the
/// app arriving while its quiet mark stands is sent on through
/// `move_to_desktop`'s own body, at its arrival and in place of the
/// arrival retile, so the Space it left is laid out once. A refusal
/// only that window could meet (a crossing, full screen) comes after
/// the verb has answered, so it reaches the log alone.
extension KiwiCore {
    /// Sends `window` on when its app's quiet open named a Desktop;
    /// true where it was moved.
    func moveQuietArrival(_ window: ManagedWindow) -> Bool {
        guard
            let desktop = launchFollow.quietDesktop(
                window.appRef.listKey,
                at: wallClock()
            )
        else { return false }
        let answer = moveToDesktop(
            "move_to_desktop",
            [
                .number(Double(desktop.number)),
                desktop.space.map { .string($0) } ?? .null,
                .number(Double(window.id.raw)),
            ],
            follow: false
        )
        if let error = answer.error {
            onLog(
                "open_in_background: w\(window.id.raw) stays — "
                    + "move to Desktop \(desktop.number) refused: \(error)"
            )
            return false
        }
        onLog(
            "open_in_background: w\(window.id.raw) sent to Desktop "
                + "\(desktop.number)"
        )
        return true
    }
}
