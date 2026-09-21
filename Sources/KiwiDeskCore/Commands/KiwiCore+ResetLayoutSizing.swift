import Foundation

/// `reset_layout_sizing` (#764): one verb that drops every
/// Space's SIZING — what `resize` accumulates — so each lands on
/// what its profile or `init.lua` authored, the global where
/// nothing was, and leaves structure alone. A resize never
/// writes the authored override (`KiwiCore+SessionRatioWrite`),
/// so the settings need no clearing; what counts as sizing is
/// stated where the store lives — `Space.resetSizing` — never
/// here.
extension KiwiCore {
    /// Dispatched through `settingsCommand`, so the one trailing
    /// `.apply` retile in `layoutCommand` shows the reset. A
    /// per-space sibling is this loop over one id.
    func resetLayoutSizing() {
        for space in state.workspaces.allSpaces {
            state.workspaces.withSpace(space.id) { $0.resetSizing() }
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
