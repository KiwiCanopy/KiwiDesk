import Foundation

extension SpaceBarManager {
    /// Records the inactive glyph whose title is expanded. The
    /// caller refreshes through the deferred bar-render door.
    func setTitleHover(_ space: SpaceID, window: WindowID?) -> Bool {
        guard let window else {
            guard titleHover?.space == space else { return false }
            titleHover = nil
            return true
        }
        guard titleHover?.space != space || titleHover?.window != window
        else { return false }
        titleHover = (space, window)
        return true
    }

    func titleHoveredWindow(in space: SpaceID) -> WindowID? {
        titleHover.flatMap { $0.space == space ? $0.window : nil }
    }
}
