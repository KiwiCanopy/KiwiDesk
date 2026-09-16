import AppKit
import Foundation

/// The one door a KiwiDesk-COMMANDED Monocle focus change takes
/// (#1391): `navigate`'s cycle, the App Bar click and
/// `pull_or_spawn`'s focus. It decides the flip, plays it, and
/// runs the ordinary `focusWindow` at the turn's midpoint — or
/// at once where no flip plays. An OS-reported focus (⌘Tab, the
/// Dock) never comes here: its swap already happened.
extension KiwiCore {
    /// `step` is the pressed direction for a directional step
    /// (`+1`/`-1`, a wrap included) and nil for a target named
    /// outright, whose sign is array order.
    func focusWithMonocleFlip(_ target: WindowID, step: Int?) {
        guard
            let (plan, current) = monocleFlipPlan(
                to: target,
                step: step
            )
        else {
            focusWindow(target, warp: true)
            return
        }
        monocleFlip.play(
            plan,
            from: face(of: current),
            to: face(of: target),
            cornerRadius: borders.cornerRadius(for: target)
        ) { [weak self] in
            self?.focusWindow(target, warp: true)
        }
    }

    /// The flip for a commanded change onto `target` with the
    /// window it leaves, or nil where none plays: the active
    /// Space is not Monocle, either window is not a tiled member
    /// of it, the setting is off, Reduce Motion is on, or the
    /// frames cannot be read.
    func monocleFlipPlan(
        to target: WindowID,
        step: Int?
    ) -> (MonocleFlipPlan, WindowID)? {
        guard let space = activeSpace, space.mode == .monocle
        else { return nil }
        let tiled = state.effectiveTiledMembers(of: space)
        guard
            let current = state.focusAnchor(of: space, tiled: tiled)
        else { return nil }
        // The issued frames: the plate lies where the window IS,
        // and a parked member's frame carries its own size.
        let frames = tiler.placedFrames(state: state)
        guard let currentFrame = frames[current],
            let targetFrame = frames[target]
        else { return nil }
        let animations = tiler.settings.animations
        let plan = MonocleFlipPlan.decide(
            current: current,
            target: target,
            members: tiled,
            step: step,
            orientation: tiler.settings
                .resolvedMonocle(for: space.id).orientation,
            currentFrame: currentFrame,
            targetSize: targetFrame.size,
            durationMS: animations.monocleFlipDurationMS,
            enabled: animations.onMonocleFocus,
            reduceMotion: monocleFlip.reduceMotion()
        )
        return plan.map { ($0, current) }
    }

    private func face(of id: WindowID) -> MonocleFlipOverlay.Face {
        let icon = state.windows[id].flatMap { window in
            NSRunningApplication(processIdentifier: window.pid)?
                .icon
        }
        return MonocleFlipOverlay.Face(icon: icon)
    }
}
