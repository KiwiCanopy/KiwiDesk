import AppKit
import Foundation

/// The two live seams a held resize glide needs (#1082), wired at
/// bootstrap like every other seam. Both are INERT by default on
/// `HoldRepeat` — the inverted-seam shape tests.md rules — because
/// the live frame clock is a `CADisplayLink` on a real screen and
/// a live default would build one in every suite that arms a
/// hold. `HoldGlideSeamTests` guards the inversion from both
/// sides: deleting a wiring reds as loudly as duplicating it.
extension KiwiCore {
    func wireHoldGlide() {
        wireGlideStep()
        wireGlideFrames()
    }

    /// The glide re-issues the PRESS's own command with a scaled
    /// delta — never the Lua binding, whose body may do more than
    /// resize (the single-command tally refuses to arm on such a
    /// body, so re-running it would contradict the arming rule).
    /// Routing through `execute` keeps the capped writers, the
    /// refusal cues and the command contract exactly as a
    /// keypress has them: a glide step is a press like any other
    /// and does not get its own path.
    private func wireGlideStep() {
        keys.holdRepeat.applyGlideStep = {
            [weak self] args, scale in
            guard let self,
                let axis = args.first?.stringValue,
                let delta = args.dropFirst().first?.numberValue
            else { return false }
            let response = self.execute(
                "resize",
                args: [.string(axis), .number(delta * scale)]
            )
            return response.isSuccess
        }
    }

    /// One `DisplayLink` on the screen the resized space lays out
    /// on, so a mixed-rate desk glides at the rate of the display
    /// being watched (the per-monitor rule in
    /// input-and-animation.md). The driver measures each frame's
    /// own `dt` and clamps a stalled one, which is what makes the
    /// ramp refresh-rate independent — and it reports a starved
    /// clock through its own live `onLog` default (#1084), which
    /// is the honest device check that the ramp is being ticked
    /// at all.
    private func wireGlideFrames() {
        keys.holdRepeat.startFrames = { [weak self] tick in
            guard let self else { return {} }
            let screen =
                self.activeSpace.flatMap {
                    TilingEngine.screen(
                        for: $0.id,
                        in: self.state
                    )
                } ?? NSScreen.main
            guard let screen else { return {} }
            let driver = DisplayLinkDriver(screen: screen) { dt in
                tick(dt)
            }
            driver.start()
            return { [driver] in
                // Pause synchronously so no further frame lands,
                // but INVALIDATE off this turn: a glide can stop
                // from inside a frame callback (a refusal cue
                // reached mid-step), and tearing the link down
                // there releases the driver — the link owns the
                // only strong reference to it — while that
                // driver's own `fire` is still on the stack.
                driver.stop()
                DispatchQueue.main.async { driver.invalidate() }
            }
        }
    }
}
