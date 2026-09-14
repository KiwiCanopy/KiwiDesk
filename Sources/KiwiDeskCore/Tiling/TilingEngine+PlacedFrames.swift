import AppKit
import CoreGraphics

/// The two frame sets a pass produces (#934): the SLOTS, which
/// every reader classifies against, and the frames the retile
/// ISSUES, where a bsp or stack slot under a learned floor is
/// placed inward. Split from `TilingEngine+Layout.swift` at the
/// file ceiling.
extension TilingEngine {
    /// The frames the retile issues: `calculatedFrames` with the
    /// split layouts' floor residue placed by the one
    /// `SplitOverflow.placed` post-pass. Read by the retile and
    /// by what acts on where a window IS — the on-window cues,
    /// the unsolicited-resize check — never by a reader that
    /// CLASSIFIES slots (`BspSplit.sides`, the drag pipeline,
    /// geometric navigation): an inward frame overlaps its
    /// neighbour by construction, which those read as a pile.
    func placedFrames(
        state: StateCoordinator
    ) -> [WindowID: CGRect] {
        visibleFrames(state: state, placed: true)
    }

    /// One loop for both sets: every visible space laid out on
    /// its own screen, unioned.
    func visibleFrames(
        state: StateCoordinator,
        placed: Bool
    ) -> [WindowID: CGRect] {
        var frames: [WindowID: CGRect] = [:]
        for placement in visiblePlacements(state: state) {
            let input = layoutInput(
                state: state,
                space: placement.space,
                screen: placement.screen
            )
            let slots = LayoutEngine.calculate(
                mode: input.space.mode,
                windows: input.tiled,
                context: input.context
            )
            let computed =
                placed
                ? SplitOverflow.placed(
                    mode: input.space.mode,
                    frames: slots,
                    context: input.context
                )
                : slots
            // Each visible space is a distinct space on a distinct
            // display, so their window sets are disjoint and the
            // union is lossless — the `new` tie-break never fires
            // in practice. It guards only the degenerate case of
            // the same space resolving onto two displays, which
            // `activeSpace(on:)` already self-heals against.
            frames.merge(computed) { _, new in new }
        }
        return frames
    }
}
