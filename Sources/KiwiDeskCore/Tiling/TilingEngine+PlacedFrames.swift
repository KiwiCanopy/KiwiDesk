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
    /// `SplitOverflow.placed` post-pass. A reader that acts on
    /// where a window IS takes this; one that CLASSIFIES slots
    /// keeps `calculatedFrames` — `FrameSetReaderCensusTests` is
    /// the register, state-and-layout.md the argument (#934).
    /// `recording: false` is a what-if reading over a state that
    /// is not live (#1869): the monocle hold the layout input
    /// records is put back, so the live engine is left as found.
    func placedFrames(
        state: StateCoordinator,
        recording: Bool = true
    ) -> [WindowID: CGRect] {
        guard !recording else {
            return visibleFrames(state: state, placed: true)
        }
        let held = monocleShownMembers
        defer { monocleShownMembers = held }
        return visibleFrames(state: state, placed: true)
    }

    /// One loop for both sets: every visible space laid out on
    /// its own screen, unioned.
    func visibleFrames(
        state: StateCoordinator,
        placed: Bool
    ) -> [WindowID: CGRect] {
        var frames: [WindowID: CGRect] = [:]
        for placement in visiblePlacements(state: state) {
            let computed = laidOut(
                layoutInput(
                    state: state,
                    space: placement.space,
                    screen: placement.screen
                ),
                placed: placed
            )
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

    /// One space's frames from its layout input: the slots, or the
    /// issued frames with the split layouts' residue placed.
    private func laidOut(
        _ input: (space: Space, tiled: [WindowID], context: LayoutContext),
        placed: Bool
    ) -> [WindowID: CGRect] {
        let slots = LayoutEngine.calculate(
            mode: input.space.mode,
            windows: input.tiled,
            context: input.context
        )
        guard placed else { return slots }
        return SplitOverflow.placed(
            mode: input.space.mode,
            frames: slots,
            context: input.context
        )
    }

    /// One space's issued frames on `screen`, the window its layout
    /// put in front and the area it fills, read without recording like
    /// `placedFrames(state:recording: false)` — the App Bar's
    /// visibility verdict (#2234), which needs only the Space its
    /// bar draws.
    func placedFrames(
        of space: Space,
        on screen: NSScreen,
        state: StateCoordinator
    ) -> (frames: [WindowID: CGRect], front: WindowID?, usable: CGRect) {
        let held = monocleShownMembers
        defer { monocleShownMembers = held }
        let input = layoutInput(state: state, space: space, screen: screen)
        return (
            laidOut(input, placed: true),
            input.context.focused,
            input.context.usable
        )
    }
}
