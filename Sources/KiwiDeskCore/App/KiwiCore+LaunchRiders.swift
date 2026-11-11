import Foundation

/// A launch's popups ride its follow (#3189): noted at their
/// arrival while the debt stands, filed into the rule's Space
/// when the follow is paid.
extension KiwiCore {
    /// Notes `window` where the create fold skipped its app rule
    /// for a popup, outside a Desktop switch's batch.
    func noteLaunchRider(
        arrived window: ManagedWindow,
        effects: AppliedEffects,
        now: Date = Date()
    ) {
        guard effects.popupSkippedRule != nil,
            !eventLoop.switchReads.applying,
            let bundleID = window.appBundleID,
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
        _ riders: [LaunchRiders.Rider],
        into space: SpaceID
    ) {
        for rider in riders {
            let window = rider.window
            let from = rider.from
            guard from != space,
                state.workspaces.space(of: window) == from,
                spaceMoveBlock(window) == nil,
                stickyMoveBlock(window, to: space) == nil
            else { continue }
            fileMembership(window, into: space, from: from)
            onLog(
                "launch follow: popup w\(window.raw) rides into "
                    + "space \(space.raw)"
            )
        }
    }
}
