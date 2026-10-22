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
    /// `SplitOverflow.placed` post-pass and a maximized window
    /// filling its screen (#2448). A reader that acts on
    /// where a window IS takes this; one that CLASSIFIES slots
    /// keeps `calculatedFrames` — `FrameSetReaderCensusTests` is
    /// the register, state-and-layout.md the argument (#934).
    /// `recording: false` is a what-if reading over a state that
    /// is not live (#1869): the monocle hold the layout input
    /// records is put back, so the live engine is left as found.
    /// `recordingCovers` is the retile's own call (#2235): it files
    /// what each scrolled run draws in `runCovers`.
    func placedFrames(
        state: StateCoordinator,
        recording: Bool = true,
        recordingCovers: Bool = false
    ) -> [WindowID: CGRect] {
        guard !recording else {
            return visibleFrames(
                state: state,
                placed: true,
                recordingCovers: recordingCovers
            )
        }
        let held = monocleShownMembers
        defer { monocleShownMembers = held }
        return visibleFrames(state: state, placed: true)
    }

    /// One loop for both sets: every visible space laid out on
    /// its own screen, unioned.
    func visibleFrames(
        state: StateCoordinator,
        placed: Bool,
        recordingCovers: Bool = false
    ) -> [WindowID: CGRect] {
        var frames: [WindowID: CGRect] = [:]
        for placement in visiblePlacements(state: state) {
            let input = layoutInput(
                state: state,
                space: placement.space,
                screen: placement.screen
            )
            // One cover per space: the record and the hidden
            // windows' slots read the same value.
            let cover =
                recordingCovers || placed && input.space.mode == .stack
                ? Self.cover(of: input) : nil
            if recordingCovers { runCovers[input.space.id] = cover }
            var computed = laidOut(input, placed: placed, cover: cover)
            if placed {
                computed = fillingMaximized(
                    computed,
                    input: input,
                    on: placement.screen,
                    state: state
                )
            }
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

    private static func cover(
        of input: (space: Space, tiled: [WindowID], context: LayoutContext)
    ) -> RunCover? {
        RunCover.of(
            space: input.space.id,
            mode: input.space.mode,
            tiled: input.tiled,
            in: input.context
        )
    }

    /// One space's frames from its layout input: the slots, or the
    /// issued frames with the split layouts' residue placed.
    /// `cover` is that input's `RunCover.of`, read on a placed
    /// stack pass.
    private func laidOut(
        _ input: (space: Space, tiled: [WindowID], context: LayoutContext),
        placed: Bool,
        cover: RunCover?
    ) -> [WindowID: CGRect] {
        let slots = LayoutEngine.calculate(
            mode: input.space.mode,
            windows: input.tiled,
            context: input.context
        )
        guard placed else { return slots }
        var issued = SplitOverflow.placed(
            mode: input.space.mode,
            frames: slots,
            context: input.context
        )
        // A run's hidden window keeps the edge slot it waits
        // behind: pulled inward it would cross the shown run
        // (#2235 ruling).
        if input.space.mode == .stack, let cover {
            for id in cover.behind.keys { issued[id] = slots[id] }
        }
        return issued
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
            fillingMaximized(
                laidOut(input, placed: true, cover: Self.cover(of: input)),
                input: input,
                on: screen,
                state: state
            ),
            input.context.focused,
            input.context.usable
        )
    }
}
