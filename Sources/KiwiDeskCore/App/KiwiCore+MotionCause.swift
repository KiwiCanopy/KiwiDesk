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

    /// Runs `body` as immediate user motion when `event` is the
    /// user's own act in an app (#2187): a removal that took the
    /// active Space's focus, or a window the frontmost app opened,
    /// within a press's grace. Any other app event stays ambient.
    func withAppActMotion(
        _ event: KiwiEvent,
        effects: AppliedEffects,
        reason: WindowGoneReason?,
        _ body: () -> Void
    ) {
        guard
            let pressedAt = appActPress(
                event,
                effects: effects,
                reason: reason
            )
        else { return body() }
        tiler.applier.motion.with(
            .user(pressedAt: pressedAt, late: false),
            body
        )
    }

    /// When the press `event` answers was made, or nil when the
    /// event is not attributed to one (#2187). A hide or minimize
    /// counts; a window that left with its Desktop is the switch's,
    /// asked as the close-return stand-down asks it.
    func appActPress(
        _ event: KiwiEvent,
        effects: AppliedEffects,
        reason: WindowGoneReason?
    ) -> Date? {
        guard let press = launchFollow.recentPress() else { return nil }
        let attributed: Bool
        if case .windowCreated(let window) = event {
            attributed = frontmostOwns(pid: window.pid)
        } else {
            attributed =
                effects.removedWindow?.focusLost == true
                && reason != .vanished
                && eventLoop.eagerDepartureInFlight == nil
        }
        guard attributed else { return nil }
        onLog("motion: an app act \(Int(press * 1000)) ms after a press")
        return wallClock().addingTimeInterval(-press)
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
            if self.tiler.animation.activeCount == 0 {
                self.runPendingZOrderRestore()
                self.runPendingFloatRaise()
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
