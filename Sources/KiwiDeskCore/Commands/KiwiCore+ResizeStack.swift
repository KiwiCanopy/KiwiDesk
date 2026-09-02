import AppKit
import Foundation

/// The stack half of the `resize` command, split out of
/// `KiwiCore+Resize` for file size (like `+ResizeFloating` and
/// `+ResizeBsp`): the master/stack split and the per-window
/// weight write.
extension KiwiCore {
    /// Focus-aware stack resize (#67), arrangement-aware
    /// (#222). The split axis (x for a left/right stack zone,
    /// y for top/bottom) moves the master/stack split in the
    /// direction that grows the FOCUSED window: focused in
    /// master → +delta raises the ratio, focused in the stack
    /// zone → +delta lowers it (the zone grows). The other
    /// axis grows the focused window's share of its zone via
    /// the per-window weights — but only when the zone lines
    /// up along that axis; a zone has no cross-axis parameter,
    /// so that resize fails like any unsupported axis.
    func resizeStack(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        let stack = tiler.settings.resolvedStack(for: space)
        let tiled = state.effectiveTiledMembers(of: space)
        let splitAxis =
            stack.stackPosition.splitsHorizontally ? "x" : "y"
        guard axis != splitAxis else {
            // Unknown focus keeps the master-grows direction
            // (the pre-#67 behavior).
            let (master, _) = StackLayout.partition(
                tiled,
                masterCount: stack.masterCount
            )
            let inMaster =
                space.focused.flatMap { focused in
                    tiled.contains(focused)
                        ? master.contains(focused) : nil
                } ?? true
            let sign: Double = inMaster ? 1 : -1
            // Interactive writes cap at the layout region's
            // effective range (#44, region since #537) — past it
            // the layout clamps and the stored value would only
            // ratchet invisibly. Two-sided since #933: each zone
            // carries its own members' effective minimums, and a
            // truncated write cues the refusal.
            writeCappedMasterRatio(
                proposed: stack.masterRatio + sign * delta / span,
                span: span,
                axis: axis,
                space: space,
                focused: space.focused,
                deltaSign: delta
            )
            return .ok()
        }
        guard let focused = space.focused,
            let column = StackLayout.column(
                containing: focused,
                in: tiled,
                masterCount: stack.masterCount
            )
        else { return .fail("no focused tiled window") }
        // The weight axis is the focused zone's own axis: a
        // vertical zone divides heights ("y"), a horizontal one
        // widths ("x"). The stack zone's axis derives from the
        // position (#222) and is always orthogonal to the split;
        // only a master zone oriented along the split axis has
        // no cross-axis parameter — perceivable no-op like
        // unsupported modes (#184).
        let (master, _) = StackLayout.partition(
            tiled,
            masterCount: stack.masterCount
        )
        let orientation =
            master.contains(focused)
            ? stack.masterOrientation
            : stack.stackPosition.stackOrientation
        let weightAxis =
            orientation == .vertical ? "y" : "x"
        guard axis == weightAxis else {
            cueUnsupportedCommand()
            return .fail(
                "no \(axis) parameter for this arrangement"
            )
        }
        guard let focusOffset = column.firstIndex(of: focused),
            column.count > 1
        else {
            return .fail("focused window is alone in its column")
        }
        // The step math (delta → weight change, grow cap,
        // clamp) is the shared #67/#128 authority; the screen
        // span stands in for the column height A — close enough
        // for a keyboard nudge, and the layout renormalizes
        // whatever we store.
        let weightFloor = StackLayout.weightFloor
        let weights = column.map {
            max(space.stackWeights[$0] ?? 1, weightFloor)
        }
        let index =
            column.distance(
                from: column.startIndex,
                to: focusOffset
            )
        // The layout divides the span minus the inner gaps
        // between the column's windows — clamping against the
        // raw span lets the stored weight cross the layout's
        // cascade check by exactly the gaps (#925's residue,
        // #933). Per-window minimums: a shrink clamps at the
        // focused window's own floor, a grow caps where the
        // first OTHER member would drop below its floor.
        let gaps = tiler.settings.gaps(for: space.id)
        let gap =
            weightAxis == "y"
            ? gaps.inner.vertical : gaps.inner.horizontal
        let outer =
            weightAxis == "y"
            ? gaps.outer.top + gaps.outer.bottom
            : gaps.outer.left + gaps.outer.right
        let effectiveSpan = StackLayout.weightedSpan(
            region: span,
            outer: Double(outer),
            innerGap: Double(gap),
            count: column.count
        )
        let members = Array(column)
        let minSizes = members.map {
            effectiveMinSize(of: $0, axis: weightAxis)
        }
        let outcome = StackLayout.weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: effectiveSpan,
            minSizes: minSizes
        )
        if delta < 0, outcome.hitOwnMinimum {
            refuseShrinkAtMinimum(focused, axis: axis)
        } else if delta > 0,
            let blocked = outcome.blockedByOther
        {
            refuseGrowAtNeighborMinimum(
                focused,
                anchor: members[blocked],
                axis: axis
            )
        }
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = outcome.value
        }
        return .ok()
    }
}
