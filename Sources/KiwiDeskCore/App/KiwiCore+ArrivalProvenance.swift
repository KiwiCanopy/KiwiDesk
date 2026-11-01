import Foundation

/// The arrival's provenance and its one late-create resolution
/// (#2630): every arrival whose create is still due is held in
/// the door until the create lands, `lateCreateBound` passes, or
/// the window goes, and `settleArrival` then pays each consumer.
/// Only what a consumer owes waits; placement, focus and the
/// retile never do.
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

    /// An arrival's provenance, read once ahead of the fold.
    func arrivalProvenance(of event: KiwiEvent) -> ArrivalProvenance? {
        guard case .windowCreated(let window) = event else { return nil }
        return arrivalProvenance(window)
    }

    /// Sends `window_created` for an arrival whose reason is known,
    /// and holds one whose create is still due.
    func announceArrival(
        _ window: ManagedWindow,
        provenance: ArrivalProvenance,
        effects: AppliedEffects
    ) {
        // An arrival held earlier under this id is sent first.
        flushHeldArrival(window.id)
        let reason = WindowAppearReason.classify(
            wasMinimized: effects.appearedWasMinimized,
            hadRememberedSpace: effects.hadRememberedSpace
                || effects.returnedToPocket,
            isNew: provenance.isNew
        )
        if reason == .returned { recentReturns[window.id] = wallClock() }
        if let reason { emitWindowCreated(window, reason: reason) }
        guard provenance == .awaitingCreate else { return }
        arrivals.hold(
            .init(
                window: window,
                space: state.workspaces.space(of: window.id),
                eventOwed: reason == nil,
                axCreate: eventLoop.arrivingFromAXCreate,
                at: wallClock()
            )
        )
        scheduleArrivalBound()
    }

    /// A create landed: a held arrival within the bound settles as
    /// created on a later turn, off the WindowServer port's drain,
    /// which the border pump waits on — a follow and a script's
    /// callback raise and retile.
    func resolveArrivalCreated(_ id: WindowID) {
        resolveExpiredArrivals()
        guard arrivals.land(id) else { return }
        deferred.schedule(.arrivalCreated, after: .zero) {
            [weak self] in
            guard let self else { return }
            for held in self.arrivals.takeLanded() {
                self.settleArrival(held, created: true)
            }
        }
    }

    /// A destroy or re-key of a held arrival settles it first, so
    /// a script sees a create before the window goes; only the hop
    /// pays a follow.
    func flushHeldArrival(_ id: WindowID) {
        guard let held = arrivals.release(id) else { return }
        settleArrival(held.waiting, created: held.landed, follows: false)
    }

    /// An exiting app's held arrivals, ahead of the fold that drops
    /// its windows with no destroy of their own.
    func flushHeldArrivals(ofExitedApp pid: pid_t) {
        for held in arrivals.held(pid: pid) { flushHeldArrival(held) }
    }

    /// Settles every held arrival past the bound as not created,
    /// logging each whose event waited (#2867): a returned or
    /// restored window never gets a create.
    func resolveExpiredArrivals() {
        for held in arrivals.releaseExpired(at: wallClock()) {
            if held.eventOwed {
                onLog(
                    "arrival: w\(held.window.id.raw) "
                        + "\(held.window.appBundleID ?? "unknown") — "
                        + "no WindowServer create within "
                        + "\(LaunchFollowIntent.lateCreateBound)s, "
                        + "reported existing (AX create: "
                        + "\(held.axCreate ? "yes" : "no"))"
                )
            }
            settleArrival(held, created: false)
        }
        scheduleArrivalBound()
    }

    /// Pays each consumer of a held arrival, in this order: the
    /// owed event, then the #2478 follow.
    private func settleArrival(
        _ held: ArrivalProvenanceDoor.Waiting,
        created: Bool,
        follows: Bool = true
    ) {
        let id = held.window.id
        if held.eventOwed {
            emitWindowCreated(
                state.windows[id] ?? held.window,
                reason: created ? .new : .existing,
                space: state.windows[id] == nil
                    ? held.space : state.workspaces.space(of: id)
            )
        }
        if created, follows {
            payLateSpawnFollow(id)
        } else {
            launchFollow.dropSpawn(of: id)
        }
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
