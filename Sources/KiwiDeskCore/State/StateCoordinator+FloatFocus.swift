import Foundation

// MARK: - Directional-focus float tier (#488)
//
// Tiled-only navigation made a visible floating window a
// directional black hole: dropped from `effectiveTiledMembers`,
// it could navigate OUT (the anchor falls back to a geometric
// search from its live frame) but nothing could ever focus BACK
// into it — `focus` dead-ended where the user plainly saw a
// window. The fix is a two-tier candidate search: tiled
// candidates always win, and floats are consulted only when no
// tiled candidate lies in the pressed direction, so pure
// tile-to-tile navigation is untouched.

extension StateCoordinator {
    /// The windows the float tier of directional `focus` may
    /// reach on `space` (#488): every floating window
    /// `effectiveMembers` shows there — the space's own
    /// float-flagged members (minus a sticky member rendering
    /// on another space, #445) plus floating sticky travelers
    /// homed elsewhere but rendering here, id-sorted.
    ///
    /// Deliberately a FILTER over `effectiveMembers`, never a
    /// third open-coded copy of its membership rules (§5 mirror
    /// rule): a future membership change there reaches focus
    /// reachability for free. Tiled travelers fall out through
    /// the `isFloating` test.
    ///
    /// Never candidates: transient overlays — a launcher/panel
    /// must not take directional focus (#300) — and native
    /// fullscreen windows, which live on their own macOS Space.
    public func floatingFocusCandidates(
        of space: Space,
        activeSpace: SpaceID? = nil
    ) -> [WindowID] {
        effectiveMembers(of: space, activeSpace: activeSpace)
            .filter { id in
                guard let window = windows[id] else {
                    return false
                }
                return window.isFloating
                    && !window.isTransientOverlay
                    && !window.isFullscreen
            }
    }
}
