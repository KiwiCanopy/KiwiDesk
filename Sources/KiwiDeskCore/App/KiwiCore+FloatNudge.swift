import AppKit
import CoreGraphics

/// The float nudge: a just-floated window keeps its exact frame,
/// so a tiled→floating toggle looks inert. A small fixed shove
/// toward the screen center acknowledges the state change.
///
/// The geometry is the pure `FloatNudge` helper; this layer only
/// snapshots the inputs (the cached state frame — never an AX
/// read on the hot path — and the window's screen) and rides the
/// existing relayout animation path via `applyFrame`, so the
/// nudge shares the engine's DisplayLink duration and easing.
extension KiwiCore {
    /// Nudges `id` toward its screen's visible-frame center.
    /// Callers gate the transition (float direction only, and
    /// only tiled→floating); the `floatNudge` setting gate lives
    /// here so a disabled nudge is a single no-op branch.
    func nudgeFloating(_ id: WindowID) {
        guard tiler.settings.floatNudge,
            let current = state.windows[id]?.frame
        else { return }
        let screen =
            NSScreen.screens.first {
                GeometryUtils.axVisibleFrame(of: $0)
                    .intersects(current)
            } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = GeometryUtils.axVisibleFrame(of: screen)
        let nudged = FloatNudge.target(
            frame: current,
            visible: visible
        )
        // `axVisibleFrame` excludes the menu bar but not the
        // App/Space Bar strips; clear those too, the same clamp
        // every float gets (#242).
        let target = floatFrameClampedClearOfBars(
            id,
            frame: nudged
        )
        tiler.applyFrame(
            id,
            from: current,
            to: target,
            animated: tiler.settings.animations.onRelayout
        )
    }
}
