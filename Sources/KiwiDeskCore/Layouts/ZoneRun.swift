import CoreGraphics

/// A Stack zone's or a Track track's scrolled run (#2235): the
/// windows shown at once, the rest waiting behind the first or
/// last shown slot. Pure; `StackLayout` and `TrackLayout` place
/// through it, and `Space.runHeads` carries where a run rests.
public struct ZoneRun: Sendable, Equatable {
    /// Indices into the zone's members, in drawn order, that are
    /// shown. Never empty for a non-empty zone.
    public let visible: Range<Int>
    /// The zone's member count.
    public let count: Int

    /// Whether the zone hides any window.
    public var hides: Bool { visible.count < count }

    /// The run taking windows from `head` while their `floors`
    /// fit `span`, moved by the smallest step that shows `focus`
    /// (#2235 ruling). `head` and `focus` are member indices; a
    /// run whose tail is shown in full is pulled back while the
    /// window before it still fits, so a close never leaves room
    /// unused. A first window whose floor exceeds the span is
    /// shown alone.
    public static func resolve(
        floors: [CGFloat],
        span: CGFloat,
        gap: CGFloat,
        head: Int?,
        focus: Int?
    ) -> ZoneRun {
        let count = floors.count
        guard count > 0 else { return ZoneRun(visible: 0..<0, count: 0) }
        func end(from start: Int) -> Int {
            var used: CGFloat = 0
            var end = start
            while end < count {
                let need = floors[end] + (end > start ? gap : 0)
                if end > start, used + need > span { break }
                used += need
                end += 1
            }
            return end
        }
        if end(from: 0) == count {
            return ZoneRun(visible: 0..<count, count: count)
        }
        var start = min(max(head ?? 0, 0), count - 1)
        if let focus, focus >= 0, focus < count {
            if focus < start {
                start = focus
            } else {
                while focus >= end(from: start) { start += 1 }
            }
        }
        while start > 0, end(from: start) == count,
            end(from: start - 1) == count
        {
            start -= 1
        }
        return ZoneRun(visible: start..<end(from: start), count: count)
    }

    /// Frames for a zone's members: the shown run shares `region`
    /// along the axis, each window getting its floor plus a
    /// weighted share of what is left; a hidden window takes the
    /// slot it waits behind. Keyed in member order.
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
}

extension LayoutContext {
    /// One window's floor for a run (#2235): the learned floor
    /// along the zone axis, or the configured minimum alone on a
    /// forced pass, which probes past learned bounds (#1055) like
    /// `TrackLayout.geometricCap`.
    func runFloor(of id: WindowID, horizontal: Bool) -> CGFloat {
        probesBeyondBounds
            ? minWindowSize.along(horizontal: horizontal)
            : learnedFloor(of: id, horizontal: horizontal)
    }
}
