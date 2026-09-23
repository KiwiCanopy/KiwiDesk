import CoreGraphics
import Foundation

/// Opening an app follows its window into the Space its app rule
/// files it in (#1599): a full Space switch with the focus, the
/// `followSwitch` shape. Owed by a launch, paid after the window's
/// arrival retile — `LaunchFollowIntent` carries the bounds.
extension KiwiCore {
    /// The one door that owes the follow — Open or Focus, and a
    /// launch-shaped activation below.
    func oweLaunchFollow(_ bundleID: String, at now: Date = Date()) {
        launchFollow.record(bundleID, at: now)
    }

    /// Another app coming forward retires the debt (the user moved
    /// on); the owing app's own activation does not, since it is
    /// the open completing. An activation owes a new one only as an
    /// OPEN: a click or key-down within `pressGrace`, of a process
    /// started within `launchGrace` or showing no other window — a
    /// reopen or an un-minimize — and no native Desktop switch
    /// within `desktopSwitchGrace`, since a switch by key press
    /// activates the arriving Desktop's app inside the press grace.
    /// A rule-placed window that arrived after the press and before
    /// this activation is paid here rather than owed.
    func noteAppActivation(
        _ activation: AppActivation,
        now: Date = Date()
    ) {
        if launchFollow.owed(at: now) != activation.bundleID {
            launchFollow.forget(keeping: activation.bundleID)
        }
        guard let bundleID = activation.bundleID,
            let press = launchFollow.pressAge?(),
            press <= LaunchFollowIntent.pressGrace,
            isOpening(activation, now: now)
        else { return }
        guard
            now.timeIntervalSince(lastDesktopSwitch)
                > LaunchFollowIntent.desktopSwitchGrace
        else {
            onLog(
                "launch follow: pid \(activation.pid) opened with a "
                    + "Desktop switch — nothing owed"
            )
            return
        }
        let pressedAt = now.addingTimeInterval(-press)
        if let placed = launchFollow.takePlacement(
            bundleID,
            since: pressedAt
        ),
            state.workspaces.space(of: placed.window) == placed.space
        {
            // This open's window is here already: follow it, or —
            // the user reached its Space first — owe nothing more.
            if placed.space != state.workspaces.activeSpace {
                onLog(
                    "launch follow: w\(placed.window.raw) arrived "
                        + "before its app's activation — following now"
                )
                followSwitch(to: placed.space, focusing: placed.window)
            }
            return
        }
        onLog("launch follow: owed to \(bundleID)")
        oweLaunchFollow(bundleID, at: now)
    }

    /// A fresh process, or one showing no window beyond a
    /// rule placement waiting for this activation: a running app
    /// that already shows one is a switch or its own spawn.
    private func isOpening(
        _ activation: AppActivation,
        now: Date
    ) -> Bool {
        if let launchedAt = activation.launchedAt,
            now.timeIntervalSince(launchedAt)
                <= LaunchFollowIntent.launchGrace
        {
            return true
        }
        let waiting = launchFollow.placement?.window
        return !state.windows.windows(pid: activation.pid).contains {
            $0.id != waiting
        }
    }

    /// Claims the follow when the create fold filed `window` by
    /// its app rule into another Space; the Space to switch to, or
    /// nil. A transient overlay never claims, so a launch's splash
    /// panel cannot spend the debt. Paid by `payLaunchFollow`
    /// after the arrival retile.
    func claimLaunchFollow(
        arrived window: ManagedWindow,
        effects: AppliedEffects,
        now: Date = Date()
    ) -> SpaceID? {
        guard let space = effects.placedByAppRule,
            let bundleID = window.appBundleID,
            state.workspaces.space(of: window.id) == space,
            state.windows[window.id]?.isTransientOverlay == false
        else { return nil }
        guard launchFollow.claim(bundleID, at: now) else {
            // Owed nothing yet: its app's activation may still come.
            launchFollow.notePlacement(
                .init(
                    window: window.id,
                    bundleID: bundleID,
                    space: space,
                    at: now
                )
            )
            return nil
        }
        return space
    }

    /// The switch itself, IN PLACE of the arrival's event retile,
    /// which would park the new window in its still-hidden Space
    /// only for the switch to bring it back: a whole
    /// `followSwitch` — settle, reissue retile, Monocle drop —
    /// since no native switch rides along. False when nothing was
    /// switched, so the caller retiles as usual.
    func payLaunchFollow(
        _ window: WindowID,
        into space: SpaceID
    ) -> Bool {
        guard state.workspaces.space(of: window) == space else {
            return false
        }
        onLog(
            "launch follow: w\(window.raw) opened into its app "
                + "rule's space \(space.raw)"
        )
        followSwitch(to: space, focusing: window, arriving: true)
        return true
    }

    /// The lesser of the seconds since the last left click and
    /// since the last key-down, from the HID system state — one
    /// permission-free read for both, since no key-down stamp
    /// exists beside `lastLeftClick`.
    static func secondsSinceUserPress() -> TimeInterval {
        min(
            CGEventSource.secondsSinceLastEventType(
                .hidSystemState,
                eventType: .leftMouseDown
            ),
            CGEventSource.secondsSinceLastEventType(
                .hidSystemState,
                eventType: .keyDown
            )
        )
    }
}
