import Foundation

extension StateCoordinator {
    /// Floating window candidates for directional focus (#488).
    /// Deliberately a FILTER over `effectiveMembers`, never a
    /// third open-coded copy of its membership rules (§5): a
    /// membership change there reaches focus reachability for
    /// free. Never candidates: transient overlays (#300) and
    /// native-fullscreen windows (#445).
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
