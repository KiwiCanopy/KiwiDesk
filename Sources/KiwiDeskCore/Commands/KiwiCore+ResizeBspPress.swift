import CoreGraphics
import Foundation

/// Whether a BSP keyboard press moves the focused window the way it
/// asks (#2969): judged on the layout at the ratio the press would
/// write to its split (#3672), before it writes.
extension KiwiCore {
    /// True where the press at `proposed` changes `focused`'s length
    /// the press's way. Otherwise cues the limit and returns false:
    /// the press writes nothing and a hold ends. Judged on the
    /// laid-out slots, not the placed frames: a slot a floor overhang
    /// lands back inward can move while its drawn frame stays, a
    /// press this cannot see (the writer's under-clamp residue).
    func bspPressMoves(
        _ focused: WindowID,
        _ press: BspSplitPress,
        axis: String,
        delta: Double,
        to proposed: Double
    ) -> Bool {
        let horizontal = axis == "x"
        func length(_ frame: CGRect?) -> CGFloat {
            frame.map { horizontal ? $0.width : $0.height } ?? 0
        }
        let base = press.drawnRatio
        let next = press.slots(at: proposed)
        let change = length(next[focused]) - length(press.slots[focused])
        guard change * (delta < 0 ? -1 : 1) <= Self.pressMovesTolerance
        else { return true }
        // A ratio moved down squeezes the owner, one moved up the rest.
        cueBspLimit(
            focused,
            axis: axis,
            delta: delta,
            squeezed: proposed < base ? [press.split.owner] : press.split.rest,
            atBound: Self.bspRatioSpent(base, to: proposed),
            press.slots
        )
        return false
    }

    /// Below this many points a trial moved nothing.
    private static let pressMovesTolerance: CGFloat = 0.01

    /// The cue for a BSP press that moves nothing it asks for. A
    /// floor wins over the ratio's limit: the window on the
    /// `squeezed` side nearest `focused` sitting at its floor
    /// (#1259's blame), else the window's own floor on a shrink, else
    /// the split's 0.1/0.9 bound (#3643), else the boundary.
    private func cueBspLimit(
        _ focused: WindowID,
        axis: String,
        delta: Double,
        squeezed: [WindowID],
        atBound: Bool,
        _ frames: [WindowID: CGRect]
    ) {
        let horizontal = axis == "x"
        func length(_ id: WindowID) -> Double {
            Double(
                frames[id].map { horizontal ? $0.width : $0.height } ?? 0
            )
        }
        let centre = frames[focused].map { CGPoint(x: $0.midX, y: $0.midY) }
        let atFloor = squeezed.filter {
            $0 != focused
                && length($0) <= plannedMinSize(of: $0, axis: axis) + 1
        }
        let stuck = atFloor.min { a, b in
            func distance(_ id: WindowID) -> CGFloat {
                guard let centre, let frame = frames[id] else { return 0 }
                return hypot(frame.midX - centre.x, frame.midY - centre.y)
            }
            return distance(a) < distance(b)
        }
        let atOwnFloor =
            length(focused) <= plannedMinSize(of: focused, axis: axis) + 1
        if let stuck {
            refuseGrowAtNeighborMinimum(focused, anchor: stuck, axis: axis)
        } else if delta < 0, atOwnFloor || !atBound {
            refuseShrinkAtMinimum(focused, axis: axis)
        } else if atBound {
            refuseRatioLimit(focused, axis: axis, grows: delta > 0)
        } else {
            refuseGrowAtBoundary(focused, axis: axis)
        }
    }
}
