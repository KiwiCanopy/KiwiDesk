import CoreGraphics
import Foundation

/// A press on the one window of a run that takes no length beside
/// windows a push sized (#2709): it draws what they leave, so its
/// press moves the nearest sized mate's length the other way, and a
/// grow past what that mate can give pushes on from there.
extension KiwiCore {
    func resizeBesideSized(
        _ focused: WindowID,
        at index: Int,
        zone: RunZone,
        context: LayoutContext,
        axis: String,
        delta: Double,
        toward side: RunZone.PushSide,
        space: Space
    ) -> CommandResponse {
        let weights = zone.shareWeights(in: context)
        let frames = zone.frames(in: context)
        let (_, bare, _) = zone.floorsAndGap(in: context)
        func drawn(_ at: Int) -> CGFloat {
            frames[zone.members[at]].map {
                zone.vertical ? $0.height : $0.width
            } ?? 0
        }
        let sized = (zone.run(in: context)?.visible ?? 0..<0)
            .filter { $0 != index && weights[$0] == 0 }
        let ahead = sized.filter { $0 < index }.max()
        let after = sized.filter { $0 > index }.min()
        guard let mate = side == .start ? ahead ?? after : after ?? ahead
        else { return .fail("the focused window is alone in its run") }
        let member = zone.members[mate]
        let step = CGFloat(delta)
        if step < 0 {
            // The mate takes back what the window gives, down to the
            // window's own floor.
            let give = min(-step, drawn(index) - bare[index])
            guard give > RunZone.unchangedTolerance else {
                refuseShrinkAtMinimum(focused, axis: axis)
                return .fail("every shown window is at its minimum")
            }
            if give < -step { refuseShrinkAtMinimum(focused, axis: axis) }
            writeLength(drawn(mate) + give, of: member, in: zone, space: space)
            return .ok()
        }
        let room = drawn(mate) - bare[mate]
        guard step > room else {
            writeLength(drawn(mate) - step, of: member, in: zone, space: space)
            return .ok()
        }
        // The mate gives all it has and the rest of the grow pushes
        // the window at the end the press moves toward — the last
        // in order for the keyboard; the window keeps drawing what
        // the sized mates leave, or the whole zone once alone.
        guard let run = zone.run(in: context) else { return .ok() }
        var shown = run.visible
        var dropped: Int?
        if shown.upperBound - 1 > index,
            side != .start || shown.lowerBound == index
        {
            dropped = shown.upperBound - 1
            shown = shown.lowerBound..<(shown.upperBound - 1)
        } else if shown.lowerBound < index {
            dropped = shown.lowerBound
            shown = (shown.lowerBound + 1)..<shown.upperBound
        }
        // A mate the push hides keeps no length; one left shown
        // keeps its floor.
        if dropped == mate {
            state.workspaces.withSpace(space.id) {
                $0.runSizes[member] = nil
            }
        } else {
            writeLength(bare[mate], of: member, in: zone, space: space)
        }
        state.workspaces.withSpace(space.id) {
            ($0.runHeads, $0.runTails) = zone.ends(
                showing: shown,
                heads: $0.runHeads,
                tails: $0.runTails
            )
        }
        if shown.count == 1 {
            writeLength(zone.span, of: focused, in: zone, space: space)
        }
        return .ok()
    }
}
