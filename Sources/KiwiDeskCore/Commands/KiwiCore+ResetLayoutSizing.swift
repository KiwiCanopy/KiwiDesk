import Foundation

/// `reset_layout_sizing` (#764): one verb that returns every
/// Space's SIZING — what `resize` accumulates — to the
/// configured value, and leaves structure alone.
///
/// Sizing is three stores: the session layer (#458), the size
/// fields of the authored per-space overrides, and the per-window
/// / per-track weights. Clearing an override field returns the
/// Space to the profile's global, never to a factory default.
/// `TrackOverride` carries no size field — the track sizes are
/// `Space.trackWeights`.
extension KiwiCore {
    /// Dispatched through `settingsCommand`, so the one trailing
    /// `.apply` retile in `layoutCommand` shows the reset.
    func resetLayoutSizing() {
        for space in state.workspaces.allSpaces {
            state.workspaces.withSpace(space.id) {
                $0.sessionRatios = SessionRatios()
                $0.stackWeights = [:]
                $0.trackWeights = [:]
            }
        }
        for (space, stored) in tiler.settings.bsp.override {
            var over = stored
            over.splitRatioH = nil
            over.splitRatioV = nil
            tiler.settings.bsp.override[space] =
                over.isEmpty ? nil : over
        }
        for (space, stored) in tiler.settings.stack.override {
            var over = stored
            over.masterRatio = nil
            tiler.settings.stack.override[space] =
                over.isEmpty ? nil : over
        }
        for (space, stored) in tiler.settings.scrolling.override {
            var over = stored
            over.slotSize = nil
            tiler.settings.scrolling.override[space] =
                over.isEmpty ? nil : over
        }
        // Only room is re-divided among windows already placed
        // (#593).
        promiseAllWindowsSpringSized()
    }
}
