import Foundation

/// Frame clock and step execution for continuous hold glide (#1082).
extension HoldGlide {
    func beginGlide() {
        guard heldID != nil else { return }
        isGliding = true
        stopFrames = startFrames { [weak self] dt in
            self?.glideFrame(dt: dt)
        }
        // Wall-clock fallback bound in case screen driver halts (#611).
        cancelBackstop = schedule(Self.maxRunSeconds) {
            [weak self] in
            guard let self, self.isGliding else { return }
            self.cancelBackstop = nil
            self.cancelRun()
            self.onOverrun()
        }
    }

    /// Advances glide motion by one frame delta dt.
    func glideFrame(dt: TimeInterval) {
        guard isGliding, heldID != nil, dt > 0 else { return }
        guard glideElapsed < Self.maxRunSeconds else {
            cancelRun()
            onOverrun()
            return
        }
        // Read ramp before banking elapsed time (`HoldGlide+Ramp.swift`).
        let scale = Self.glideSteps(elapsed: glideElapsed) * dt
        glideElapsed += dt
        let command = glideCommand
        let args = glideArgs
        isApplyingGlideStep = true
        defer { isApplyingGlideStep = false }
        guard applyGlideStep(command, args, scale) else {
            cancelRun()
            return
        }
    }
}
