import CoreGraphics
import Foundation

/// The screen handoff (#2548): a Space switch that moves focus
/// onto another screen carries the pointer there, whether or not
/// *mouse follows focus* is on — macOS opens Spotlight and a new
/// window on the pointer's screen. Pure, so the gates stay
/// testable; `docs/design-decisions.md` argues the ruling.
enum ScreenHandoff {
    /// The frame the pointer is warped into, or nil where the
    /// switch is no handoff: the focus stayed on its screen (or
    /// either screen is unknown), or the pointer is already on
    /// the target screen. An unknown pointer screen hands off.
    /// `window` is the focused window's frame on arrival, nil
    /// for an empty Space, whose landing is `screen` — the target
    /// screen's visible frame.
    static func frame(
        from prior: DisplayID?,
        to target: DisplayID?,
        pointerOn pointer: DisplayID?,
        window: CGRect?,
        screen: CGRect?
    ) -> CGRect? {
        guard let prior, let target, prior != target,
            pointer != target
        else { return nil }
        return window ?? screen
    }
}

extension KiwiCore {
    /// A switch's pointer move, at intent time: the screen
    /// handoff where the switch crossed screens, else the
    /// setting's own warp to `next`. A handoff warps at once
    /// rather than through the #689 hold — its target is named
    /// here, so no drain churned it — and never under a held
    /// button.
    func warpForSwitch(
        to space: SpaceID,
        focusing next: WindowID?,
        leaving prior: DisplayID?
    ) {
        let target = state.workspaces.display(of: space)
        // The reads below run only where the focus crossed.
        let crossed = prior != nil && target != nil && prior != target
        let handoff =
            crossed
            ? ScreenHandoff.frame(
                from: prior,
                to: target,
                pointerOn: mouse.pointerDisplay(),
                window: next.flatMap(warpFrame(of:)),
                screen: target.flatMap(handoffScreenFrame(of:))
            ) : nil
        guard let handoff else {
            if let next { warpMouseToFocused(next) }
            return
        }
        guard !mouse.anyButtonHeld else { return }
        pendingMouseWarp = nil
        pointerWarp?(handoff)
    }

    /// The target screen's visible frame (AX space), the empty
    /// Space's landing; nil for a screen not connected. Read off
    /// the one `displayFrames` topology the screen hop reads.
    func handoffScreenFrame(of display: DisplayID) -> CGRect? {
        tiler.displayFrames().first { $0.id == display }?.frame
    }
}
