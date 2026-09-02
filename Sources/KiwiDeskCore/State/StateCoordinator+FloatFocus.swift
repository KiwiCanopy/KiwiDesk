import Foundation

extension StateCoordinator {
    /// Floating window candidate list for directional focus on space
    /// (#300, #445, #488).
    public func floatingFocusCandidates(
        of space: Space
    ) -> [WindowID] {
        effectiveMembers(of: space)
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
