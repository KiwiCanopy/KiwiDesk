import Foundation

/// `reset_layout_sizing` (#764): one verb that returns every
/// Space's SIZING — what `resize` accumulates — to the global,
/// and leaves structure alone. What counts as sizing is stated
/// where the stores live — `Space.resetSizing` and
/// `TilingSettings.clearSizingOverrides` — never here.
extension KiwiCore {
    /// Dispatched through `settingsCommand`, so the one trailing
    /// `.apply` retile in `layoutCommand` shows the reset. A
    /// per-space sibling is this loop over one id.
    func resetLayoutSizing() {
        for space in state.workspaces.allSpaces {
            state.workspaces.withSpace(space.id) { $0.resetSizing() }
            tiler.settings.clearSizingOverrides(for: space.id)
        }
        // Only room is re-divided among windows already placed
        // (#593). A cleared track weight can change which windows
        // overlap, and the retile is the dispatcher's trailer, so
        // the restore is RECORDED for it rather than armed here —
        // armed now it would run off the pre-reset frames (#153,
        // #674).
        promiseAllWindowsSpringSized()
        if activeTrackOverflows {
            requestZOrderRestoreAfterDispatch()
        }
    }
}
