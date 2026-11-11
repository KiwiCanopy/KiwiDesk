import Foundation

/// A launch's popups ride its follow (#3189): noted at their
/// arrival while the debt stands, filed into the rule's Space
/// when the follow is paid.
extension KiwiCore {
    /// Notes `window` on its app's standing debt where the create
    /// fold skipped its app rule for a popup.
    func noteLaunchRider(
        arrived window: ManagedWindow,
        effects: AppliedEffects,
        now: Date
    ) {
        guard effects.popupSkippedRule != nil,
            let bundleID = window.appRef.listKey,
            let from = state.workspaces.space(of: window.id)
        else { return }
        launchFollow.noteRider(
            .init(window: window.id, from: from),
            of: bundleID,
            at: now
        )
    }

    /// Files a paid follow's `riders` into `space`, ahead of its
    /// switch: each still in the Space it opened in, so one the
    /// user moved since stays. No cue: nobody asked.
    func fileLaunchRiders(
        _ riders: [LaunchFollowIntent.Rider],
        into space: SpaceID
    ) {
        for rider in riders {
            let window = rider.window
            guard state.workspaces.space(of: window) == rider.from,
                spaceMoveBlock(window) == nil,
                stickyMoveBlock(window, to: space) == nil
            else { continue }
            fileMembership(window, into: space, from: rider.from)
            onLog(
                "launch follow: popup w\(window.raw) rides into "
                    + "space \(space.raw)"
            )
        }
    }
}
