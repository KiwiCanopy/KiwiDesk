import Foundation

/// The focus-driven retile's animation choice, split from
/// `KiwiCore+FocusRaise.swift` at the §2.1 ceiling.
extension KiwiCore {
    /// Whether a focus-driven re-layout animates. Scrolling's
    /// focus slide is toggleable (`on_scrolling`); Monocle
    /// animates under `stack` (the retile is a no-op, the raise
    /// is the visible change) but SNAPS under `park` (#881):
    /// park and un-park take the instant `applyInstant` path,
    /// keeping the raise-only feel instead of sliding windows
    /// to and from the corner. Used by
    /// `retileWithScrollDuration`'s non-scrolling branch — the
    /// scrolling branch swaps in `scrollDurationMS` and always
    /// animates when `on_scrolling` is set.
    var focusRetileAnimated: Bool {
        guard let space = activeSpace else { return true }
        switch space.mode {
        case .scrolling:
            return tiler.settings.animations.onScrolling
        case .monocle:
            return tiler.settings.resolvedMonocle(for: space.id)
                .hideStyle == .stack
        default:
            return true
        }
    }

    /// Retiles for a focus-driven layout, honouring
    /// `scrollDurationMS` when the active mode is scrolling and
    /// `onScrolling` is true — so scroll focus shifts animate at
    /// their own duration without touching the general one.
    ///
    /// Safe to call on MainActor: `retile()` is synchronous and
    /// reads `durationMS` at call time, so the transient swap
    /// cannot race anything.
    func retileWithScrollDuration() {
        if activeSpace?.mode == .scrolling,
            tiler.settings.animations.onScrolling
        {
            let saved = tiler.animation.durationMS
            tiler.animation.durationMS =
                tiler.animation.scrollDurationMS
            retile(animated: true)
            tiler.animation.durationMS = saved
        } else {
            retile(animated: focusRetileAnimated)
        }
    }
}
