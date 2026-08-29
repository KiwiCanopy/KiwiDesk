import Foundation

/// The glide's RUN machinery (#1082), split from `HoldGlide` at
/// §2.1's ceiling rather than after crossing it: starting the
/// frame clock, the per-frame step, and the two nets under a run
/// whose stop signal is a single Carbon event. The ladder's
/// eligibility tally and lifecycle stay on the type itself; the
/// velocity ramp is `HoldGlide+Ramp.swift`.
extension HoldGlide {
    func beginGlide() {
        guard heldID != nil else { return }
        isGliding = true
        stopFrames = startFrames { [weak self] dt in
            self?.glideFrame(dt: dt)
        }
        // A WALL-CLOCK backstop under the simulated-frame bound
        // (architect review, 2026-08-29). The frame bound is the
        // right primary — a starved queue must not age a glide it
        // never ticked (#611's idiom) — but it is spent by a
        // clock that can STOP: the driver is bound to one
        // `NSScreen`, and display sleep or a disconnect mid-hold
        // freezes `glideElapsed`, leaving the run armed for the
        // session. That is the same class of cause as the lost
        // release the bound exists for, so the net must not
        // depend on the thing that died. It can never truncate a
        // healthy glide: frame time is at most wall time, so this
        // fires no earlier than the frame bound would have.
        cancelBackstop = schedule(Self.maxRunSeconds) {
            [weak self] in
            guard let self, self.isGliding else { return }
            self.cancelBackstop = nil
            self.cancelRun()
            self.onOverrun()
        }
    }

    /// One display frame of glide: move the ramp's current speed
    /// for the time this frame actually took. `dt` arrives
    /// clamped by the driver, so a stalled frame costs distance
    /// rather than lurching a whole stall's worth in one step.
    func glideFrame(dt: TimeInterval) {
        guard isGliding, heldID != nil, dt > 0 else { return }
        guard glideElapsed < Self.maxRunSeconds else {
            cancelRun()
            onOverrun()
            return
        }
        // The ramp is read BEFORE the frame is banked, so the
        // first frame moves at `glideStartSteps` rather than one
        // frame's worth into the ramp.
        let scale = Self.glideSteps(elapsed: glideElapsed) * dt
        glideElapsed += dt
        let command = glideCommand
        let args = glideArgs
        isApplyingGlideStep = true
        defer { isApplyingGlideStep = false }
        guard applyGlideStep(command, args, scale) else {
            // Already cancelled if the step cued a refusal; a
            // second cancel is idempotent.
            cancelRun()
            return
        }
    }
}
