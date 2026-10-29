import CoreGraphics

/// A Stack zone's or a Track track's scrolled run (#2235): the
/// windows shown at once, the rest waiting beyond the first or
/// last shown slot, parked by `RunZone`. Pure; `StackLayout`
/// and `TrackLayout` place through it, and `Space.runHeads`
/// carries where a run rests.
public struct ZoneRun: Sendable, Equatable {
    /// Indices into the zone's members, in drawn order, that are
    /// shown. Never empty for a non-empty zone.
    public let visible: Range<Int>
    /// The zone's member count.
    public let count: Int

    /// Whether the zone hides any window.
    public var hides: Bool { visible.count < count }

    /// The run between `head` and `tail` where both still fit,
    /// moved by the smallest step that shows `focus` (#2235
    /// rulings, owner 2026-10-22): a focus past the run becomes
    /// its last window, with windows dropped from the other end
    /// only until the floors fit `span`, so a step reveals the
    /// focused window and nothing beyond it. With no stored tail
    /// the run takes windows from `head` while they fit. All
    /// three are member indices. A window whose floor exceeds the
    /// span is shown alone.
    public static func resolve(
        floors: [CGFloat],
        span: CGFloat,
        gap: CGFloat,
        head: Int?,
        tail: Int? = nil,
        focus: Int?
    ) -> ZoneRun {
        let count = floors.count
        guard count > 0 else { return ZoneRun(visible: 0..<0, count: 0) }
        func fits(_ start: Int, _ last: Int) -> Bool {
            let used = floors[start...last].reduce(0, +)
            return start == last
                || used + gap * CGFloat(last - start) <= span
        }
        guard !fits(0, count - 1) else {
            return ZoneRun(visible: 0..<count, count: count)
        }
        var start = min(max(head ?? 0, 0), count - 1)
        var last = start
        // A tail a removal handed back past the head reads as the
        // head alone: a stale end never refills the run.
        if let tail, tail < count {
            last = max(tail, start)
        } else {
            while last + 1 < count, fits(start, last + 1) { last += 1 }
        }
        let focus = focus.flatMap { (0..<count).contains($0) ? $0 : nil }
        if let focus, focus > last {
            last = focus
            while !fits(start, last) { start += 1 }
        } else if let focus, focus < start {
            start = focus
            while !fits(start, last) { last -= 1 }
        }
        // A run that no longer fits — a window joined it, a floor
        // was learned — gives up the end away from the focus.
        while !fits(start, last) {
            if let focus, focus == last { start += 1 } else { last -= 1 }
        }
        return ZoneRun(visible: start..<(last + 1), count: count)
    }

    /// Frames for a zone's members: the shown run shares `region`
    /// along the axis, each window getting its floor plus a
    /// weighted share of what is left; a hidden window is handed
    /// the edge slot it waits beyond, which `RunZone` parks. Keyed
    /// in member order.
    public func frames(
        floors: [CGFloat],
        weights: [Double],
        in region: CGRect,
        vertical: Bool,
        gap: CGFloat
    ) -> [CGRect] {
        guard count > 0 else { return [] }
        let span = vertical ? region.height : region.width
        let shown = Array(visible)
        let available =
            span - gap * CGFloat(max(shown.count - 1, 0))
        let floorTotal = shown.reduce(CGFloat(0)) { $0 + floors[$1] }
        let weightTotal = shown.reduce(0.0) { $0 + weights[$1] }
        let extra = max(available - floorTotal, 0)
        var slots: [CGRect] = []
        var position = vertical ? region.minY : region.minX
        for index in shown {
            let extent =
                shown.count == 1
                ? available
                : floors[index]
                    + extra * CGFloat(weights[index] / weightTotal)
            slots.append(
                vertical
                    ? CGRect(
                        x: region.minX,
                        y: position,
                        width: region.width,
                        height: extent
                    )
                    : CGRect(
                        x: position,
                        y: region.minY,
                        width: extent,
                        height: region.height
                    )
            )
            position += extent + gap
        }
        return (0..<count).map { index in
            if index < visible.lowerBound { return slots[0] }
            if index >= visible.upperBound { return slots[slots.count - 1] }
            return slots[index - visible.lowerBound]
        }
    }

    /// The member `heads` names as this zone's resting head: the
    /// last one in the zone, since a head handed on by a removal
    /// can land ahead of the zone's own (`Space.remove`).
    public static func head(
        of members: [WindowID],
        in heads: Set<WindowID>
    ) -> Int? {
        members.lastIndex { heads.contains($0) }
    }

    /// The member `tails` names as this zone's resting tail: the
    /// first one in the zone, since a tail handed back by a
    /// removal can land past the zone's own (`Space.remove`).
    public static func tail(
        of members: [WindowID],
        in tails: Set<WindowID>
    ) -> Int? {
        members.firstIndex { tails.contains($0) }
    }
}

extension LayoutContext {
    /// One window's floor for a run's shape (#2235): the learned
    /// floor, or the configured minimum alone on a forced pass,
    /// which probes past learned bounds (#1055) like
    /// `TrackLayout.geometricCap`.
    func runFloor(of id: WindowID, horizontal: Bool) -> CGFloat {
        probesBeyondBounds
            ? minWindowSize.along(horizontal: horizontal)
            : learnedFloor(of: id, horizontal: horizontal)
    }

    /// The floor a run plans a member at along its own axis:
    /// `runFloor` raised to the member's least refusal there
    /// (`EffectiveSizeBound.refusedFloor`, #2774), stood down on a
    /// forced pass.
    func plannedFloor(of id: WindowID, horizontal: Bool) -> CGFloat {
        let floor = runFloor(of: id, horizontal: horizontal)
        guard !probesBeyondBounds else { return floor }
        return max(
            floor,
            sizeBounds[id]?.refusedFloor(horizontal: horizontal) ?? 0
        )
    }
}
