import Foundation

/// Which events earn a retile. Split from `TilingEngine.swift`
/// at the §2.1 hard ceiling (#913 tipped it over): a pure,
/// `nonisolated` classifier over `KiwiEvent` has no need of the
/// engine's stored state, so it is the piece that leaves
/// cleanly.
extension TilingEngine {
    /// Events that change window structure and require a
    /// retile. Move/resize events are deliberately excluded:
    /// applying frames emits them, which would loop. Focus
    /// changes are handled separately — only focus-driven
    /// layouts (Scrolling, Monocle) re-layout on focus.
    public nonisolated static func shouldRetile(
        after event: KiwiEvent
    ) -> Bool {
        switch event {
        case .windowCreated, .windowDestroyed, .appTerminated,
            .displaysChanged, .windowFloatChanged,
            .windowRekeyed, .windowFullscreenChanged,
            .windowHidden:
            // A re-key swaps the tracked id in one slot; the newly
            // active tab must be placed into that slot's frame
            // (#308), so retile even though the array shape is
            // unchanged.
            // A fullscreen flip changes layout membership like a
            // float flip (#670): entering exempts the slot (the
            // window keeps it, but macOS moved it to its own
            // Space), leaving must re-place it.
            // A hide removes the window from the layout like a
            // close does (#913) — the survivors must close over
            // the gap it leaves.
            return true
        case .appLaunched, .windowFocused, .windowMoved,
            .windowResized, .windowTitleChanged,
            .desktopChanged:
            return false
        }
    }
}
