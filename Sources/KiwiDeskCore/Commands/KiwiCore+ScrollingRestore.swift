import CoreGraphics
import Foundation

/// The scrolling z-order restore (#2985), split out of
/// `KiwiCore+ZOrder` at the §2.1 ceiling. The plan's math is
/// `KiwiCore+ZOrderMath`'s.
extension KiwiCore {
    /// Scrolling: columns pushed past the screen edges are
    /// clamped there by macOS and pile up, overlapping. Each
    /// side must stack toward its own edge — the column
    /// nearest the focus on top, farther ones underneath —
    /// so the piles read as the row receding to the left and
    /// to the right of the viewport. Only what shows is raised:
    /// a long row's whole sequence outran the drain's budget,
    /// leaving the shown windows, raised last, unverified. With
    /// nothing to raise the anchor is lifted over the floor, as in
    /// Monocle's restore, so the reliable raise and the closing
    /// re-assert still run.
    func restoreScrollingZOrder(_ space: Space) {
        guard let plan = scrollingPlan(of: space) else { return }
        guard plan.raise.isEmpty else {
            raiseSequentially(
                plan.raise,
                thenFocus: plan.anchor,
                above: plan.floor,
                front: plan.anchor
            )
            return
        }
        raiseSequentially(
            plan.anchor.map { [$0] } ?? [],
            thenFocus: plan.anchor,
            above: plan.floor
        )
    }

    /// The restore this Space's row owes now, judged on the slots
    /// (`FrameSetReaderCensusTests`). Anchor, not `space.focused`
    /// (#431): the pile split follows a traveler's slot too.
    private func scrollingPlan(
        of space: Space
    ) -> (
        raise: [WindowID],
        floor: [WindowID],
        shown: [WindowID],
        anchor: WindowID?
    )? {
        let tiled = state.effectiveTiledMembers(of: space)
        guard tiled.count > 1,
            let usable = tiler.layoutInput(state: state)?.context.usable
        else { return nil }
        let anchor = state.focusAnchor(of: space, tiled: tiled)
        let plan = Self.scrollingRestorePlan(
            tiled,
            focusIndex: anchor.flatMap { tiled.firstIndex(of: $0) } ?? 0,
            frames: tiler.calculatedFrames(state: state),
            on: usable
        )
        return (plan.raise, plan.floor, plan.shown, anchor)
    }

    /// Whether a focus step owes a restore. False from a focused
    /// float, as `scrollFocusJumpsSlots` is: no evidence of a move
    /// along the row, and a spurious restack buries that float.
    func scrollFocusStepShowsOthers(
        to target: WindowID,
        from previous: WindowID?
    ) -> Bool {
        guard let previous, previous != target, let space = activeSpace,
            state.effectiveTiledMembers(of: space).contains(previous)
        else { return false }
        return scrollingRowShowsOthers(leaving: previous)
    }

    /// Whether the row now shows a window nothing raised, past the
    /// one the focus just left, whose order a whole-row restore no
    /// longer keeps. Nil `previous` asks of every shown window, as
    /// a close does, whose focus left the row.
    func scrollingRowShowsOthers(leaving previous: WindowID?) -> Bool {
        guard let space = activeSpace, space.mode == .scrolling,
            let plan = scrollingPlan(of: space)
        else { return false }
        return plan.shown.contains { $0 != previous }
    }
}
