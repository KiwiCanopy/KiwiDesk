import CoreGraphics
import Foundation

/// Opening an app follows its window into the Space its app rule
/// files it in (#1599): switch there AND focus it, the #1007
/// hand-off. Owed by a press-caused activation, paid at the
/// window's arrival — `LaunchFollowIntent` carries the bounds.
extension KiwiCore {
    /// The adoption heal's cadence (`adoptionHealInterval`), which
    /// `LaunchFollowIntent.drainWindow` is derived from.
    static let adoptionHealDefault: Duration = .seconds(5)

    /// Every activation retires the last debt — the user moved on
    /// — and a press-caused one outside a Desktop switch owes a
    /// new one. The switch arm matters: a switch by key press
    /// activates the arriving Desktop's app within the grace, and
    /// its windows would otherwise follow their rules.
    func noteAppActivation(_ pid: pid_t) {
        launchFollow.forget()
        guard let age = launchFollow.pressAge?(),
            age <= LaunchFollowIntent.pressGrace
        else { return }
        guard
            Date().timeIntervalSince(lastDesktopSwitch)
                > LaunchFollowIntent.desktopSwitchGrace
        else {
            onLog(
                "launch follow: pid \(pid) activated with a "
                    + "Desktop switch — nothing owed"
            )
            return
        }
        launchFollow.record(pid)
    }

    /// Pays the follow when the create fold filed `window` by its
    /// app rule into another Space. A transient overlay never
    /// claims, so a launch's splash panel cannot spend the debt.
    func payLaunchFollow(
        arrived window: ManagedWindow,
        effects: AppliedEffects
    ) {
        guard let space = effects.placedByAppRule,
            space != state.workspaces.activeSpace,
            state.workspaces.space(of: window.id) == space,
            state.windows[window.id]?.isTransientOverlay == false,
            launchFollow.claim(window.pid)
        else { return }
        onLog(
            "launch follow: w\(window.id.raw) opened into its app "
                + "rule's space \(space.raw)"
        )
        handFollowFocus(to: window.id, in: space)
    }

    /// The lesser of the seconds since the last left click and
    /// since the last key-down, from the HID system state — a
    /// public read that needs no Input Monitoring grant.
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
