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
    /// reach on `space` (#488): the space's own float-flagged
    /// members plus floating sticky travelers homed elsewhere
    /// but RENDERING here (#445), id-sorted for determinism.
    ///
    /// Never candidates: transient overlays — a launcher/panel
    /// must not take directional focus (#300) — and native
    /// fullscreen windows, which live on their own macOS Space.
    /// A sticky float member that renders on ANOTHER space has
    /// physically traveled away and is dropped, mirroring the
    /// tiled filter in `effectiveTiledMembers`.
    public func floatingFocusCandidates(
        of space: Space,
        activeSpace: SpaceID? = nil
    ) -> [WindowID] {
        let focused = activeSpace ?? workspaces.activeSpace
        let members = space.windows.filter { id in
            guard let window = windows[id],
                window.isFloating,
                isFloatFocusCandidate(window)
            else { return false }
            guard window.isSticky else { return true }
            return stickyRenderSpace(of: window, focused: focused)
                == space.id
        }
        let travelers = windows.all
            .filter {
                $0.isSticky && $0.isFloating
                    && isFloatFocusCandidate($0)
                    && !space.windows.contains($0.id)
                    && stickyRenderSpace(of: $0, focused: focused)
                        == space.id
            }
            .map(\.id)
            .sorted { $0.raw < $1.raw }
        return members + travelers
    }

    private func isFloatFocusCandidate(
        _ window: ManagedWindow
    ) -> Bool {
        !window.isTransientOverlay && !window.isFullscreen
    }
}
