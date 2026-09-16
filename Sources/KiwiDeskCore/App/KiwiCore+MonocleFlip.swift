import AppKit
import Foundation

/// The one door a KiwiDesk-COMMANDED Monocle focus change takes
/// (#1391): `navigate`'s cycle, the App Bar click and
/// `pull_or_spawn`'s focus. It decides the flip, plays it, and
/// runs the ordinary `focusWindow` once the blur covers the
/// surface — or at once where no flip plays. A press during a
/// play lands at once too and RETARGETS the running card rather
/// than restarting it: a burst is navigation, and the motion
/// stays one motion. An OS-reported focus never comes here: its
/// swap already happened.
extension KiwiCore {
    /// `step` is the pressed direction for a directional step
    /// (`+1`/`-1`, a wrap included) and nil for a target named
    /// outright, whose sign is array order.
    func focusWithMonocleFlip(_ target: WindowID, step: Int?) {
        // A play in flight: its focus lands here, ahead of the
        // anchor read — the App Bar click reaches this door
        // without passing `execute` — then the press lands at
        // once and the running card retargets.
        if monocleFlip.isPlaying {
            runPendingMonocleFocus()
            focusWindow(target, warp: true)
            monocleFlip.retarget(to: face(of: target))
            return
        }
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
            cornerRadii: (
                borders.cornerRadius(for: current),
                borders.cornerRadius(for: target)
            )
        ) { [weak self] in
            self?.runPendingMonocleFocus()
        }
        // Written AFTER `play`, whose opening `end()` fires any
        // earlier landing — a debt recorded first would be
        // landed by it.
        pendingMonocleFocus = (from: current, to: target)
    }

    /// Lands the focus a playing flip owes, once: the ordinary
    /// `focusWindow`, unless the window is gone, its Space is no
    /// longer the active one, or an honored report already
    /// dropped the debt. Called at the landing, by the door
    /// ending a play, and ahead of every command that reads the
    /// focused window.
    func runPendingMonocleFocus() {
        guard let pending = pendingMonocleFocus else { return }
        pendingMonocleFocus = nil
        guard state.windows[pending.to] != nil,
            state.workspaces.space(of: pending.to)
                == state.workspaces.activeSpace
        else { return }
        focusWindow(pending.to, warp: true)
    }

    /// Ends a play in flight with its focus landed — the door's
    /// own settle, and the one that drops the panel.
    func endMonocleFlip() {
        monocleFlip.end()
        runPendingMonocleFocus()
    }

    /// Ends a play in flight and forgets its focus — the Space
    /// switch's, whose own raise picks the focus on arrival.
    func dropMonocleFlip() {
        pendingMonocleFocus = nil
        monocleFlip.end()
    }

    /// The flip for a commanded change onto `target` with the
    /// window it leaves, or nil where none plays: the setting is
    /// off, Reduce Motion is on, the active Space is not Monocle,
    /// either window is not a tiled member of it, or the frames
    /// cannot be read. The cheap stand-downs come first, ahead of
    /// the layout pass the frames cost.
    func monocleFlipPlan(
        to target: WindowID,
        step: Int?
    ) -> (MonocleFlipPlan, WindowID)? {
        let animations = tiler.settings.animations
        let reduceMotion = monocleFlip.reduceMotion()
        guard animations.onMonocleFocus, !reduceMotion,
            let space = activeSpace, space.mode == .monocle
        else { return nil }
        let tiled = state.effectiveTiledMembers(of: space)
        guard
            let current = state.focusAnchor(of: space, tiled: tiled),
            current != target, tiled.contains(target)
        else { return nil }
        // The issued frames: the plate lies where the window IS,
        // and a parked member's frame carries its own size.
        let frames = tiler.placedFrames(state: state)
        guard let currentFrame = frames[current],
            let targetFrame = frames[target]
        else { return nil }
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
            reduceMotion: reduceMotion
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
