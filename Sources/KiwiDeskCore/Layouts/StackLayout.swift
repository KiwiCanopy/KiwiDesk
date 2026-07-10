import CoreGraphics

/// Master/Stack layout over the flat array.
///
/// The first `masterCount` windows form the master zone (left),
/// everything after is the stack zone (right column). The zone
/// boundary is just an index — no containers (see 03_Layout).
public struct StackLayout: LayoutSystem {
    public init() {}

    /// Renormalization floor applied when *reading* a stack
    /// weight (#67) — shared with the `resize` command so the
    /// command's step math and the layout's distribution can
    /// never disagree on the domain. Deliberately below
    /// `weightRange.lowerBound`: the command never stores a
    /// value this small, so the floor only defends against a
    /// future writer — do not collapse the two constants.
    public static let weightFloor: Double = 0.05
    /// Clamp for what the `resize` command *stores* (#67).
    public static let weightRange: ClosedRange<Double> = 0.1...10

    /// The master_ratio interval that keeps BOTH zones at
    /// least `minSize` wide within `available` points (#44),
    /// or nil when two min-size zones cannot coexist at any
    /// ratio — the cascade case. `minSize` ≤ 0 (or NaN) means
    /// no minimum: the full 0...1, which also fences nonsense
    /// stored ratios away from negative zone widths. The
    /// single authority behind the layout's effective clamp
    /// and the interactive write cap (parity rule).
    public static func effectiveRatioRange(
        available: Double,
        minSize: Double
    ) -> ClosedRange<Double>? {
        // A degenerate region (gaps wider than the usable
        // area) cascades regardless of the minimum.
        guard available > 0 else { return nil }
        guard minSize > 0 else { return 0...1 }
        guard available >= minSize * 2 else { return nil }
        let fraction = minSize / available
        return fraction...(1 - fraction)
    }

    /// Caps an interactive master_ratio write at the current
    /// display's effective range (#44): past it the layout
    /// clamps anyway and the stored value would only ratchet
    /// invisibly — the same rule as the #67 weight cap. Never
    /// pushes the value back across `base`, so an already
    /// out-of-range value stays editable in the direction
    /// that re-enters the range. (The config verb
    /// `stack.set_master_ratio` deliberately stays wide: the
    /// stored value is honored again on a wider display.)
    public static func cappedRatioWrite(
        _ proposed: Double,
        base: Double,
        available: Double,
        minSize: Double
    ) -> Double {
        guard
            let range = effectiveRatioRange(
                available: available,
                minSize: minSize
            )
        else { return proposed }
        if proposed > base {
            return min(proposed, max(range.upperBound, base))
        }
        if proposed < base {
            return max(proposed, min(range.lowerBound, base))
        }
        return proposed
    }

    /// The largest weight total a column can carry before its
    /// smallest share drops below `minSize` — the single
    /// authority behind both the layout's cascade check and
    /// the resize command's growth cap, so the two formulas
    /// cannot drift apart (#67 review; parity rule).
    public static func maxColumnTotal(
        smallestWeight: Double,
        height: Double,
        minSize: Double
    ) -> Double {
        // No (or nonsense) minimum → no cliff, matching the
        // old `share < minSize` comparison for minSize ≤ 0.
        guard minSize > 0 else { return .infinity }
        return smallestWeight * height / minSize
    }

    /// The master/stack partition of a tiled window array —
    /// the single authority consumed by `calculateGeometry`
    /// and the `resize` command (#67 review: a third
    /// hand-mirror of this rule had crept in). `stack` is nil
    /// while everything still fits in the master zone.
    public static func partition(
        _ windows: [WindowID],
        masterCount: Int
    ) -> (
        master: ArraySlice<WindowID>,
        stack: ArraySlice<WindowID>?
    ) {
        let boundary = max(1, masterCount)
        guard windows.count > boundary else {
            return (windows[...], nil)
        }
        return (windows[..<boundary], windows[boundary...])
    }

    /// The column (zone) of `partition` holding `member`, or
    /// nil when it is not in `windows`.
    public static func column(
        containing member: WindowID,
        in windows: [WindowID],
        masterCount: Int
    ) -> ArraySlice<WindowID>? {
        guard let index = windows.firstIndex(of: member) else {
            return nil
        }
        let (master, stack) = partition(
            windows,
            masterCount: masterCount
        )
        guard let stack, index >= master.endIndex else {
            return master
        }
        return stack
    }

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        guard !windows.isEmpty else { return [:] }
        let (master, stack) = Self.partition(
            windows,
            masterCount: context.stack.masterCount
        )

        guard let stack else {
            // Master only: full width.
            return column(
                master,
                in: usable,
                context: context
            )
        }

        let gap = context.gaps.inner.horizontal
        let available = usable.width - gap
        // The cascade is a genuine last resort: only when two
        // min-size zones cannot coexist at ANY ratio (#44). A
        // merely extreme master_ratio is clamped to the widest
        // value that keeps both zones ≥ min_window_size — the
        // stored config value stays untouched, so it is honored
        // again on a wider display.
        guard
            let range = Self.effectiveRatioRange(
                available: Double(available),
                minSize: Double(context.minWindowSize)
            )
        else {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }
        let ratio = CGFloat(
            min(
                max(
                    context.stack.masterRatio,
                    range.lowerBound
                ),
                range.upperBound
            )
        )
        let masterWidth = available * ratio
        let stackWidth = available - masterWidth

        let masterRegion = CGRect(
            x: usable.minX,
            y: usable.minY,
            width: masterWidth,
            height: usable.height
        )
        let stackRegion = CGRect(
            x: usable.minX + masterWidth + gap,
            y: usable.minY,
            width: stackWidth,
            height: usable.height
        )

        var result = column(
            master,
            in: masterRegion,
            context: context
        )
        result.merge(
            column(
                stack,
                in: stackRegion,
                context: context
            )
        ) { _, new in new }
        return result
    }

    /// Distributes windows vertically in a region, sized
    /// proportionally to their `stackWeights` (#67; absent =
    /// 1.0, so unweighted columns stay even). When the
    /// smallest weighted share stops fitting, weighting steps
    /// aside: as many windows as possible stay fully tiled
    /// (evenly) and only the overflow collapses into a
    /// title-bar cascade at the bottom.
    private func column(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let count = CGFloat(windows.count)
        guard count > 0 else { return [:] }
        let gap = context.gaps.inner.vertical
        let available = region.height - gap * (count - 1)
        let weights = windows.map {
            max(context.stackWeights[$0] ?? 1, Self.weightFloor)
        }
        let total = weights.reduce(0, +)
        let limit = Self.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            height: Double(available),
            minSize: Double(context.minWindowSize)
        )
        if total > limit {
            if context.stack.overflowStyle == .cascadeAll {
                return OverlapStack.frames(
                    for: windows,
                    in: region,
                    minSize: context.minWindowSize
                )
            }
            return overflowColumn(
                windows,
                in: region,
                context: context
            )
        }
        var result: [WindowID: CGRect] = [:]
        var y = region.minY
        for (offset, window) in windows.enumerated() {
            let height =
                available * weights[offset] / total
            result[window] = CGRect(
                x: region.minX,
                y: y,
                width: region.width,
                height: height
            )
            y += height + gap
        }
        return result
    }

    /// Column overflow: the first `tiled` windows keep at
    /// least `minWindowSize`, the rest cascade at the bottom
    /// with a fixed title-bar offset — the block's last
    /// window fully visible, the buried ones showing their
    /// title bars above it. Nothing extends past the region.
    private func overflowColumn(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let minSize = context.minWindowSize
        let gap = context.gaps.inner.vertical
        let offset = OverlapStack.offset
        let ids = Array(windows)
        for tiled in stride(
            from: ids.count - 1,
            through: 1,
            by: -1
        ) {
            let buried = CGFloat(ids.count - tiled - 1)
            let cascadeHeight = minSize + offset * buried
            let tileHeight =
                (region.height - cascadeHeight
                    - gap * CGFloat(tiled))
                / CGFloat(tiled)
            guard tileHeight >= minSize else { continue }
            var result: [WindowID: CGRect] = [:]
            var y = region.minY
            for id in ids[..<tiled] {
                result[id] = CGRect(
                    x: region.minX,
                    y: y,
                    width: region.width,
                    height: tileHeight
                )
                y += tileHeight + gap
            }
            for (index, id) in ids[tiled...].enumerated() {
                result[id] = CGRect(
                    x: region.minX,
                    y: y + CGFloat(index) * offset,
                    width: region.width,
                    height: minSize
                )
            }
            return result
        }
        // Not even one full window fits above the cascade:
        // the whole region cascades (emergency fallback).
        return OverlapStack.frames(
            for: windows,
            in: region,
            minSize: minSize
        )
    }
}

// MARK: - Stack zone array operations (see 03_Layout_Engine)

extension Space {
    /// Moves a stack-zone window into the master zone by
    /// swapping it with the last master window.
    public mutating func promote(
        _ window: WindowID,
        masterCount: Int
    ) {
        let boundary = max(1, masterCount)
        guard let index = windows.firstIndex(of: window),
            index >= boundary,
            boundary - 1 < windows.count
        else { return }
        windows.swapAt(index, boundary - 1)
    }

    /// Moves a master-zone window into the stack zone by
    /// swapping it with the first stack window.
    public mutating func demote(
        _ window: WindowID,
        masterCount: Int
    ) {
        let boundary = max(1, masterCount)
        guard let index = windows.firstIndex(of: window),
            index < boundary,
            boundary < windows.count
        else { return }
        windows.swapAt(index, boundary)
    }
}
