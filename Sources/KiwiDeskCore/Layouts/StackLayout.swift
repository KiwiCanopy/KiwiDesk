import CoreGraphics

/// Master/Stack layout over the flat array.
///
/// The first `masterCount` windows form the master zone,
/// everything after is the stack zone. The zone boundary is
/// just an index — no containers (see 03_Layout). Where the
/// stack zone sits (`stack_position`) and how the master zone
/// lines up its windows (`master_orientation`) are parameters
/// (#222); the stack zone's lineup derives from the position
/// (`StackPosition.stackOrientation`). The default is master
/// left / stack right (the classic dwm split) with multiple
/// masters side by side (`master_orientation` `horizontal`).
public struct StackLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        guard !windows.isEmpty else { return [:] }
        let params = context.stack
        let (master, stack) = Self.partition(
            windows,
            masterCount: params.masterCount
        )

        // #313: render order for the master zone. Mirrored, the
        // boundary master sits at the stack seam instead of the
        // far edge. Applied in the master-only branch too, so
        // closing the last stack window never reorders masters.
        let masterOrdered =
            Self.mirrorsMasterZone(params)
            ? ArraySlice(master.reversed())
            : master

        guard let stack else {
            // Master only: the full usable region.
            return zone(
                masterOrdered,
                in: usable,
                vertical: params.masterOrientation == .vertical,
                context: context
            )
        }

        let horizontal = params.stackPosition.splitsHorizontally
        let gap =
            horizontal
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let available =
            (horizontal ? usable.width : usable.height) - gap
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
                    params.masterRatio,
                    range.lowerBound
                ),
                range.upperBound
            )
        )
        let masterSpan = available * ratio
        let (masterRegion, stackRegion) = Self.regions(
            usable: usable,
            position: params.stackPosition,
            masterSpan: masterSpan,
            stackSpan: available - masterSpan,
            gap: gap
        )

        var result = zone(
            masterOrdered,
            in: masterRegion,
            vertical: params.masterOrientation == .vertical,
            context: context
        )
        result.merge(
            zone(
                stack,
                in: stackRegion,
                vertical: params.stackPosition.stackOrientation
                    == .vertical,
                context: context
            )
        ) { _, new in new }
        return result
    }

    /// #313: whether the master zone lays its slots from the
    /// stack seam instead of the region's min edge. True when
    /// the stack *leads* (`left`/`top`) AND the master lineup
    /// runs *parallel* to the split axis — otherwise the
    /// boundary master (index `masterCount − 1`) would render
    /// at the point farthest from the stack, and every boundary
    /// crossing (minimize-promotion, `promote`/`demote`) would
    /// teleport across the master zone. A pure render mapping:
    /// array order and the promote/demote swaps stay untouched,
    /// and geometric navigation follows the frames. Deliberately
    /// NOT applied to perpendicular lineups — there every master
    /// already touches the seam, and reversing would flip the
    /// natural top-to-bottom (left-to-right) reading for no seam
    /// gain. Side effect, accepted: in a mirrored zone the
    /// `cascade_overflow` pile at the trailing end holds the
    /// array-earliest masters instead of the latest — the pile
    /// keeps its screen position and downward cascade either
    /// way. `StackSchematic` mirrors in lockstep via this same
    /// predicate.
    public static func mirrorsMasterZone(
        _ params: StackParams
    ) -> Bool {
        let leads =
            params.stackPosition == .left
            || params.stackPosition == .top
        guard leads else { return false }
        let parallel: StackParams.Orientation =
            params.stackPosition.splitsHorizontally
            ? .horizontal : .vertical
        return params.masterOrientation == parallel
    }

    /// The master and stack regions for a split of the usable
    /// area (#222): the split axis follows `position`
    /// (`left`/`right` divide the width, `top`/`bottom` the
    /// height), each zone spanning the full cross axis.
    static func regions(
        usable: CGRect,
        position: StackParams.StackPosition,
        masterSpan: CGFloat,
        stackSpan: CGFloat,
        gap: CGFloat
    ) -> (master: CGRect, stack: CGRect) {
        switch position {
        case .right:
            let master = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: masterSpan,
                height: usable.height
            )
            let stack = CGRect(
                x: usable.minX + masterSpan + gap,
                y: usable.minY,
                width: stackSpan,
                height: usable.height
            )
            return (master, stack)
        case .left:
            let stack = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: stackSpan,
                height: usable.height
            )
            let master = CGRect(
                x: usable.minX + stackSpan + gap,
                y: usable.minY,
                width: masterSpan,
                height: usable.height
            )
            return (master, stack)
        case .bottom:
            let master = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: usable.width,
                height: masterSpan
            )
            let stack = CGRect(
                x: usable.minX,
                y: usable.minY + masterSpan + gap,
                width: usable.width,
                height: stackSpan
            )
            return (master, stack)
        case .top:
            let stack = CGRect(
                x: usable.minX,
                y: usable.minY,
                width: usable.width,
                height: stackSpan
            )
            let master = CGRect(
                x: usable.minX,
                y: usable.minY + stackSpan + gap,
                width: usable.width,
                height: masterSpan
            )
            return (master, stack)
        }
    }

    /// Distributes windows along one axis of a region — a
    /// column when `vertical`, a row otherwise (#222) — sized
    /// proportionally to their `stackWeights` (#67; absent =
    /// 1.0, so unweighted zones stay even). When the smallest
    /// weighted share stops fitting, weighting steps aside: as
    /// many windows as possible stay fully tiled (evenly) and
    /// only the overflow collapses into a title-bar cascade at
    /// the zone's trailing end (the pile itself always offsets
    /// downward — `OverlapStack`).
    private func zone(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        vertical: Bool,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let count = CGFloat(windows.count)
        guard count > 0 else { return [:] }
        let gap =
            vertical
            ? context.gaps.inner.vertical
            : context.gaps.inner.horizontal
        let span = vertical ? region.height : region.width
        let available = span - gap * (count - 1)
        let weights = windows.map {
            max(context.stackWeights[$0] ?? 1, Self.weightFloor)
        }
        let total = weights.reduce(0, +)
        let limit = Self.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            span: Double(available),
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
            return overflowZone(
                windows,
                in: region,
                vertical: vertical,
                context: context
            )
        }
        var result: [WindowID: CGRect] = [:]
        var position = vertical ? region.minY : region.minX
        for (offset, window) in windows.enumerated() {
            let extent =
                available * weights[offset] / total
            result[window] =
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
            position += extent + gap
        }
        return result
    }

    /// Zone overflow: the first `tiled` windows keep at
    /// least `minWindowSize`, the rest cascade at the zone's
    /// trailing end with a fixed title-bar offset — the
    /// block's last window fully visible, the buried ones
    /// showing their title bars above it. Nothing extends
    /// past the region.
    private func overflowZone(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        vertical: Bool,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let ids = Array(windows)
        guard
            let rects = OverlapStack.overflowFrames(
                count: ids.count,
                in: region,
                vertical: vertical,
                minSize: context.minWindowSize,
                gap: vertical
                    ? context.gaps.inner.vertical
                    : context.gaps.inner.horizontal
            )
        else {
            // Not even one full window fits above the cascade:
            // the whole region cascades (emergency fallback).
            return OverlapStack.frames(
                for: windows,
                in: region,
                minSize: context.minWindowSize
            )
        }
        return Dictionary(
            uniqueKeysWithValues: zip(ids, rects)
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
