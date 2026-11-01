import Foundation

/// The arrival's provenance and its late-create resolution
/// (#2630): `window_created` is sent at the arrival when its
/// reason is known, else once the create lands (`new`) or
/// `LaunchFollowIntent.lateCreateBound` passes (`existing`).
/// Only the emission waits; placement, focus and the retile never
/// do. The #2478 follow's late payment resolves here too.
extension KiwiCore {
    /// The door's create ledger (#2478).
    var windowCreates: WindowCreateLedger { arrivals.ledger }

    /// `window`'s provenance, read through the one door.
    func arrivalProvenance(_ window: ManagedWindow) -> ArrivalProvenance {
        arrivals.provenance(
            of: window.id,
            bootStep: eventLoop.adoptsAsBootStep(pid: window.pid),
            own: EventLoop.isOwnProcess(window.pid),
            now: wallClock()
        )
    }

    /// Sends `window_created` for an arrival, or holds it for its
    /// create.
    func announceArrival(
        _ window: ManagedWindow,
        effects: AppliedEffects
    ) {
        let provenance = arrivalProvenance(window)
        let reason = WindowAppearReason.classify(
            wasMinimized: effects.appearedWasMinimized,
            hadRememberedSpace: effects.hadRememberedSpace
                || effects.returnedToPocket,
            isNew: provenance.isNew
        )
        if reason == .returned { recentReturns[window.id] = wallClock() }
        guard let reason else {
            arrivals.hold(
                .init(
                    window: window,
                    space: state.workspaces.space(of: window.id),
                    axCreate: eventLoop.arrivingFromAXCreate,
                    at: wallClock()
                )
            )
            scheduleArrivalBound()
            return
        }
        emitWindowCreated(window, reason: reason)
    }

    /// A create landed: a held arrival within the bound resolves
    /// `new`, and the follow's spawn slot pays, off the port's
    /// drain, since a follow raises and retiles.
    func resolveArrivalCreated(_ id: WindowID) {
        resolveExpiredArrivals()
        guard let held = arrivals.release(id) else { return }
        sendHeldArrival(held, reason: .new)
        if launchFollow.spawn?.window == id {
            deferred.schedule(.lateSpawnFollow, after: .zero) {
                [weak self] in self?.payLateSpawnFollow(id)
            }
        }
    }

    /// A destroy or re-key of a held arrival sends its event
    /// first, so a script sees a create before the window goes.
    func flushHeldArrival(_ id: WindowID) {
        guard let held = arrivals.release(id) else { return }
        launchFollow.dropSpawn(of: id)
        sendHeldArrival(held, reason: .existing)
    }

    /// Resolves every held arrival past the bound as `existing`,
    /// logging each (#2867).
    func resolveExpiredArrivals() {
        for held in arrivals.releaseExpired(at: wallClock()) {
            let id = held.window.id
            onLog(
                "arrival: w\(id.raw) "
                    + "\(held.window.appBundleID ?? "unknown") — "
                    + "no WindowServer create within "
                    + "\(LaunchFollowIntent.lateCreateBound)s, "
                    + "reported existing (AX create: "
                    + "\(held.axCreate ? "yes" : "no"))"
            )
            launchFollow.dropSpawn(of: id)
            sendHeldArrival(held, reason: .existing)
        }
        scheduleArrivalBound()
    }

    private func sendHeldArrival(
        _ held: ArrivalProvenanceDoor.Waiting,
        reason: WindowAppearReason
    ) {
        let id = held.window.id
        emitWindowCreated(
            state.windows[id] ?? held.window,
            reason: reason,
            space: state.windows[id] == nil
                ? held.space : state.workspaces.space(of: id)
        )
    }

    /// Arms the one timer at the earliest held arrival's bound.
    private func scheduleArrivalBound() {
        guard let deadline = arrivals.nextDeadline else {
            deferred.cancel(.arrivalBound)
            return
        }
        let wait = max(0, deadline.timeIntervalSince(wallClock()))
        deferred.schedule(
            .arrivalBound,
            after: .milliseconds(Int((wait * 1_000).rounded(.up)))
        ) { [weak self] in self?.resolveExpiredArrivals() }
    }
}
