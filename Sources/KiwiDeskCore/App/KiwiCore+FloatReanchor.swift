import AppKit
import CoreGraphics

/// Cross-display re-anchor for floating windows (#444).
///
/// Delivery deliberately rides the stash-capture machinery: the
/// translated frame is seeded as the float's stash "original",
/// and `restoreStashed` — which already handles echo lag, the
/// drag exemption, and removed displays — applies it on the
/// retile every move already runs. That is instant when the
/// target space is visible on its monitor, and deferred to the
/// activation that un-parks the float when it is not. No second
/// apply path to drift. (Stickies are the one exception — see
/// below: they never park, so they apply directly.)
extension KiwiCore {
    /// Re-anchors `id` onto `target`'s display when that differs
    /// from the display its frame sits on — every float-flagged
    /// window, plus any window bound for a floating-MODE space
    /// (#498, `EffectiveFloat`). No-op for tiled windows
    /// bound for tiling spaces (the layout owns their frames),
    /// same-display moves (#412 stash behavior unchanged),
    /// global stickies (visible everywhere, so a membership move
    /// never needs to teleport one), and a window mid-drag (the
    /// pointer owns its placement — the spring-drop exclusion,
    /// generalized; the quick chip drop is unaffected, its
    /// exemption clears before `moveWindow` runs). Callers run
    /// this AFTER the membership move so the target space
    /// resolves the bars.
    func reanchorFloat(_ id: WindowID, to target: SpaceID) {
        guard let window = state.windows[id],
            EffectiveFloat.applies(
                isFloating: window.isFloating,
                mode: state.workspaces[target]?.mode
            ),
            window.stickyScope != .global,
            tiler.dragExemptWindow != id
        else { return }
        // A parked float's state frame is the stash corner; the
        // pending capture is the real frame to translate.
        let base = tiler.stashOriginal(id) ?? window.frame
        guard
            let targetScreen = TilingEngine.screen(
                for: target,
                in: state
            ),
            let sourceScreen = TilingEngine.screen(
                containing: base
            ) ?? NSScreen.main ?? NSScreen.screens.first
        else { return }
        let source = GeometryUtils.axVisibleFrame(
            of: sourceScreen
        )
        let dest = GeometryUtils.axVisibleFrame(of: targetScreen)
        guard source != dest else { return }
        let translated = FloatReanchor.target(
            frame: base,
            from: source,
            to: dest,
            scaleSize: tiler.settings.floatScaleOnDisplayChange
        )
        // Clear of the strips painted for the target space TODAY
        // — the same clamp every float gets (#242). A parked
        // target paints none, so a deferred delivery may land
        // under a future bar for a retile; the
        // `clampFloatsClearOfBars` net corrects it on
        // activation.
        let clamped = floatFrameClampedClearOfBars(
            id,
            frame: translated
        )
        // A DISPLAY sticky re-homes across monitors
        // (`stickyMoveRefused` allows it) but never parks — it
        // is stash-exempt on its home display — so a seeded
        // capture might never be delivered while the window
        // stays visible on the wrong monitor, and any user move
        // would silently wipe the seed (`forgetStash`). No
        // park/restore cycle to ride: apply directly, dropping
        // any stale capture so a restore can't fight the frame.
        // A non-flagged window bound for a floating-MODE space
        // (#498) also applies directly: the stash machinery only
        // captures frames for float-FLAGGED windows, so a seeded
        // capture would never be delivered for it.
        if window.isSticky || !window.isFloating {
            tiler.forgetStash(id)
            tiler.applyFrame(
                id,
                from: window.frame,
                to: clamped,
                animated: tiler.settings.animations.onRelayout
            )
        } else {
            tiler.seedStash(id, frame: clamped)
        }
    }

    /// Re-anchors every floating member of `space` onto its
    /// (possibly new) display — the space-level sibling of the
    /// `moveWindow` re-anchor (#444), used by the space
    /// relocation and rehome paths. Same-display members no-op
    /// inside `reanchorFloat`.
    func reanchorFloats(of space: SpaceID) {
        for id in state.workspaces[space]?.windows ?? [] {
            reanchorFloat(id, to: space)
        }
    }
}
