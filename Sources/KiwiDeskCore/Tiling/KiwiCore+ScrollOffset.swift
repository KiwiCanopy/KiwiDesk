import AppKit
import Foundation

/// Persists the scrolling layout's viewport offset across
/// retiles (#66), split out of `KiwiCore` for file size.
///
/// `ScrollingLayout` is a pure function of `(windows, context)`,
/// and `context.scrollOffset` is where it reads "where the
/// viewport was last." Something has to close that loop by
/// writing the offset the layout just chose back onto the
/// space — otherwise every retile would see `nil` and the
/// scroll-into-view minimal-pan behavior (the #66 fix) would
/// never engage. `KiwiCore` is the natural owner: it already
/// mutates `Space` fields for every other command (stack
/// weights, focus), and `TilingEngine` stays read-only over
/// state, applying frames without touching it.
extension KiwiCore {
    /// Re-derives and stores the scrolling viewport offset for
    /// the active space, if it is in scrolling mode. Called after
    /// every retile so the next focus move has an accurate
    /// "previous offset" to scroll minimally from. Reads the
    /// same `layoutInput` the retile's frames came from, so the
    /// stored offset always matches what was materialized. An
    /// emptied space keeps its last offset — harmless, every
    /// consumer re-clamps against the live row.
    func persistScrollOffset() {
        guard let input = tiler.layoutInput(state: state),
            input.space.mode == .scrolling,
            !input.tiled.isEmpty
        else { return }
        let offset = ScrollingLayout.viewportOffset(
            for: input.tiled,
            in: input.context
        )
        state.workspaces.withSpace(input.space.id) {
            $0.scrollOffset = offset
        }
    }
}
