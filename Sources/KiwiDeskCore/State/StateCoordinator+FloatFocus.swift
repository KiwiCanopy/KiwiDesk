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

    /// Whether `id` may occupy a space's `focused` slot (#671).
    ///
    /// False for a **transient overlay** — a context menu, a
    /// panel, any window floating for a structural reason (#300).
    /// Such a window is the OS's to focus and un-focus: macOS
    /// grants it focus while it is up and returns focus
    /// underneath the moment it goes away, and it emits no event
    /// on the way out that KiwiDesk could reconcile from. Letting
    /// it into the slot therefore made every consumer of the slot
    /// — the ring, the App Bar's active item, a focus-driven
    /// pan, and the close-time fallback handoff with its AX raise
    /// and pointer warp — track a window the user is not working
    /// in, and then hand the slot to an arbitrary array neighbour
    /// when it closed. Keeping it out is one rule at the stamp
    /// instead of a correction at each consumer.
    ///
    /// **Every seam that writes a space's `focused` consults
    /// this** — the create fold, the focus-report fold, and the
    /// two "nothing focused, take the first member" fallbacks.
    /// The rule is in `.claude/rules/state-and-layout.md`;
    /// `TransientOverlayFocusTests` pins the seams that exist.
    ///
    /// Deliberately keyed on the structural flag and not on
    /// `isFloating`, exactly as the ring is: a window the user
    /// floated through a `float_rules` entry is an ordinary
    /// window and holds focus like one.
    public func mayHoldSpaceFocus(_ id: WindowID) -> Bool {
        windows[id]?.isTransientOverlay != true
    }
}
