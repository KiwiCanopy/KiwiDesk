import CoreGraphics
import Foundation

/// Opening an app follows its window into the Space its app rule
/// files it in (#1599): a full Space switch with the focus, the
/// `followSwitch` shape. Owed by a launch, paid after the window's
/// arrival retile — `LaunchFollowIntent` carries the bounds. A new
/// window created while KiwiDesk watched follows owed nothing
/// (#2478), on `spawnVerdict`.
extension KiwiCore {
    /// The one door that owes the follow — Open or Focus, and a
    /// launch-shaped activation below.
    func oweLaunchFollow(_ bundleID: String, at now: Date = Date()) {
        launchFollow.record(bundleID, at: now)
    }

    /// Another app coming forward retires the debt (the user moved
    /// on); the owing app's own activation does not, since it is
    /// the open completing. An activation owes a new one only as an
    /// OPEN: a process a press started (`openingPress`), and no
    /// native Desktop switch within `desktopSwitchGrace`, since a
    /// switch by key press activates the arriving Desktop's app
    /// inside the press grace.
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
            let press = openingPress(of: activation, now: now)
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

    /// The age of the press that opened `activation`, else nil: a
    /// press at most `pressGrace` before the process started — a
    /// cold start activates seconds later (#2201) — or one within
    /// `pressGrace` of the activation of an opening process.
    private func openingPress(
        of activation: AppActivation,
        now: Date
    ) -> TimeInterval? {
        if let launchedAt = activation.launchedAt,
            let press = launchFollow.pressBefore(
                startedAgo: now.timeIntervalSince(launchedAt)
            )
        {
            return press
        }
        guard let press = launchFollow.recentPress(),
            isOpening(activation, now: now)
        else { return nil }
        return press
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
    /// panel cannot spend the debt, and neither does a window a
    /// Desktop switch's batch reveals (#2347). Owed nothing, the
    /// window still follows on `spawnVerdict` (#2478). Paid by
    /// `payLaunchFollow` after the arrival retile.
    func claimLaunchFollow(
        arrived window: ManagedWindow,
        provenance: ArrivalProvenance,
        effects: AppliedEffects,
        now: Date = Date()
    ) -> SpaceID? {
        guard !eventLoop.switchReads.applying,
            let space = effects.placedByAppRule,
            let bundleID = window.appBundleID,
            state.workspaces.space(of: window.id) == space,
            state.windows[window.id]?.isTransientOverlay == false
        else { return nil }
        guard launchFollow.claim(bundleID, at: now) else {
            switch spawnVerdict(window, provenance: provenance) {
            case .follows:
                onLog(
                    "launch follow: w\(window.id.raw), a new window "
                        + "of pid \(window.pid), follows its rule"
                )
                return space
            case .awaitsCreate:
                launchFollow.noteSpawn(
                    .init(
                        window: window.id,
                        bundleID: bundleID,
                        space: space,
                        from: state.workspaces.activeSpace
                    )
                )
            case .stays:
                break
            }
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

    /// What the unowed arm (#2478) makes of a rule-filed arrival:
    /// `spawnStandsClear`, then `spawnFollows`; then created while
    /// KiwiDesk watched, or a create still due. One clock,
    /// `wallClock`, for every reading.
    enum SpawnVerdict { case follows, awaitsCreate, stays }

    func spawnVerdict(
        _ window: ManagedWindow,
        provenance: ArrivalProvenance
    ) -> SpawnVerdict {
        let now = wallClock()
        guard spawnStandsClear(at: now),
            launchFollow.spawnFollows(pid: window.pid)
        else { return .stays }
        switch provenance {
        case .created: return .follows
        case .awaitingCreate: return .awaitsCreate
        case .own, .unreported, .existing: return .stays
        }
    }

    /// The unowed arm's stand-downs, asked at the claim and again
    /// at a late payment: the route live, boot done, no sweep
    /// chunk deferring, no app's launch debt standing, clear of a
    /// Desktop switch.
    private func spawnStandsClear(at now: Date) -> Bool {
        windowCreates.isLive && boot.reachedReady
            && !defersEventRetiles
            && launchFollow.owed(at: now) == nil
            && now.timeIntervalSince(lastDesktopSwitch)
                > LaunchFollowIntent.desktopSwitchGrace
    }

    /// Pays the unowed follow when `id`'s create lands after its
    /// arrival (#2478), within the bound the arrival door resolved
    /// (#2630): the arrival retile has parked the window in its
    /// unshown Space, so this is a whole `followSwitch`.
    func payLateSpawnFollow(_ id: WindowID) {
        let now = wallClock()
        guard let spawn = launchFollow.takeSpawn(id),
            spawnStandsClear(at: now),
            state.workspaces.activeSpace == spawn.from,
            state.workspaces.space(of: id) == spawn.space,
            spawn.space != state.workspaces.activeSpace
        else { return }
        onLog(
            "launch follow: w\(id.raw) created after its arrival "
                + "— following now"
        )
        followSwitch(to: spawn.space, focusing: id)
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
