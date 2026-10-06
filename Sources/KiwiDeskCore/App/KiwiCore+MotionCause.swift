import Foundation

/// Whose window motion this is (#804 ▸ Ruling 1–3). An entry point
/// a KiwiDesk control drives opens the user scope once; a hotkey
/// reads as one through the existing `keys.isFiring`; everything
/// else, the CLI/IPC socket included, reads as ambient.
/// `MotionScopeCensusTests` holds who opens the scope.
extension KiwiCore {
    /// The cause the frame writes of this turn belong to.
    var motionCause: MotionCause {
        if let open = tiler.applier.motion.current { return open }
        if keys.isFiring || keys.holdGlide.isApplyingGlideStep {
            return .user(pressedAt: wallClock(), late: false)
        }
        return .ambient
    }

    /// Runs `body` as motion a KiwiDesk control is making now. An
    /// open immediate user scope keeps its own press time; a late
    /// one is made immediate.
    @discardableResult
    public func withUserMotion<T, E: Error>(
        _ body: () throws(E) -> T
    ) throws(E) -> T {
        if case .user(_, late: false)? = tiler.applier.motion.current {
            return try body()
        }
        return try tiler.applier.motion.with(
            .user(pressedAt: wallClock(), late: false),
            body
        )
    }

    /// Deferred tails carry their scheduler's cause, late (Ruling 2).
    func wireMotionCause() {
        tiler.motionGate.cause = { [weak self] in
            self?.motionCause ?? .ambient
        }
        tiler.motionGate.clock = { [applier = tiler.applier] in
            applier.clock()
        }
        tiler.motionGate.quiescence.buttonsDown = { [weak self] in
            (self?.mouse.pressedButtons() ?? 0) != 0
        }
        tiler.motionGate.release = { [weak self] owed in
            guard let self else { return }
            self.retile(
                animated: owed.animated,
                pass: owed.pass,
                newlyCreatedWindow: owed.newlyCreatedWindow,
                sizing: owed.sizing
            )
            // A restore that waited for this pass rides its settle,
            // or runs now when nothing animates.
            if self.pendingZOrderRestore,
                self.tiler.animation.activeCount == 0
            {
                self.runPendingZOrderRestore()
            }
        }
        tiler.applier.cause = { [weak self] in
            self?.motionCause ?? .ambient
        }
        deferred.captureCause = { [weak self] in
            self?.motionCause ?? .ambient
        }
        deferred.runUnder = { [weak self] cause, body in
            guard let self else { return body() }
            self.tiler.applier.motion.with(cause, body)
        }
    }
}
