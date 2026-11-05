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
            let input = tiler.layoutInput(state: state)
        else { return nil }
        let anchor = state.focusAnchor(of: space, tiled: tiled)
        // A focused float has no slot: the slot the layout seats then
        // decides what is buried, as it decides the frames.
        let seated =
            anchor.flatMap { tiled.contains($0) ? $0 : nil }
            ?? ScrollingLayout.subject(of: tiled, context: input.context)
        let plan = Self.scrollingRestorePlan(
            tiled,
            focusIndex: seated.flatMap { tiled.firstIndex(of: $0) } ?? 0,
            frames: tiler.calculatedFrames(state: state),
            on: input.context.usable
        )
        return (plan.raise, plan.floor, plan.shown, anchor)
    }

    /// Whether a focus move along the row owes a restore: the row
    /// moved, by the pass's persisted offset against `offsetBefore`,
    /// and shows another window. False unless both ends are in the
    /// row, as `scrollFocusJumpsSlots` is: a restore buries floats
    /// (#418), and a focused float owes no raise that lifts them
    /// back. A held pass pans later, and a drain still running was
    /// planned for the old focus.
    func scrollFocusMoveOwesRestore(
        to target: WindowID,
        from previous: WindowID?,
        offsetBefore: CGFloat?
    ) -> Bool {
        guard let previous, previous != target, let space = activeSpace,
            space.mode == .scrolling
        else { return false }
        let tiled = state.effectiveTiledMembers(of: space)
        guard tiled.contains(previous), tiled.contains(target) else {
            return false
        }
        let moved =
            space.scrollRest?.offset != offsetBefore
            || tiler.motionGate.owed != nil
            || floatRaiseDebt.restoresInFlight > 0
        return moved && scrollingRowShowsOthers(leaving: previous)
    }

    /// The focus report's arm (#2985): a click or an app's activation
    /// pans the row with no command behind it. Our own raise's echo
    /// moved no focus, so the ask refuses it. Not macOS restoring a
    /// Desktop's focus, since a drain's quiet raises have no #1345
    /// gate and the draw list shows both Desktops mid-switch.
    func armReportedScrollMove(
        to id: WindowID,
        from previous: WindowID?,
        offsetBefore: CGFloat?,
        now: Date
    ) {
        guard !eventLoop.isWithinSpaceSwitchGrace(now: now),
            !isRestoredDesktopFocus(id, now: now),
            scrollFocusMoveOwesRestore(
                to: id,
                from: previous,
                offsetBefore: offsetBefore
            )
        else { return }
        scheduleScrollingZOrderRestoreIfOverflowing()
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
