import CoreGraphics

/// Master/Stack layout over flat window array (#222).
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

        // Mirrored master order keeps boundary master at stack seam (#313).
        let masterOrdered =
            Self.mirrorsMasterZone(params)
            ? ArraySlice(master.reversed())
            : master

        let horizontal = params.stackPosition.splitsHorizontally
        let gap =
            horizontal
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let available =
            (horizontal ? usable.width : usable.height) - gap
        // Cascades if min-size zones cannot coexist (#44).
        let range = SplitDomain.effectiveRatioRange(
            available: Double(available),
            minSize: Double(context.minWindowSize)
        )

        guard let stack else {
            // Master only: the full usable region — unless the one
            // window keeps its zone (#1389).
            if let range,
                Self.loneMasterKeepsZone(
                    windows,
                    params: params,
                    range: range
                )
            {
                let masterSpan = Self.masterSpan(
                    available: available,
                    ratio: params.masterRatio,
                    in: range
                )
                return zone(
                    masterOrdered,
                    in: Self.regions(
                        usable: usable,
                        position: params.stackPosition,
                        masterSpan: masterSpan,
                        stackSpan: available - masterSpan,
                        gap: gap
                    ).master,
                    vertical: params.masterOrientation == .vertical,
                    context: context
                )
            }
            return zone(
                masterOrdered,
                in: usable,
                vertical: params.masterOrientation == .vertical,
                context: context
            )
        }

        guard let range else {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }
        let masterSpan = Self.masterSpan(
            available: available,
            ratio: params.masterRatio,
            in: range
        )
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

    /// Whether master zone renders from stack seam (`StackSchematic`, #313).
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

    /// Whether the split RENDERS its ratio for a lone member: with
    /// `fill_when_alone` off the one window keeps the master zone
    /// the two-window split gives it (#1389). The one home of that
    /// verdict — the engine draws by it and the resize cues judge
    /// "nothing to divide" by it (#1258), never by a member count.
    /// `range` is `SplitDomain.effectiveRatioRange`'s answer for
    /// the region: nil means no two zones fit, and the window
    /// fills.
    public static func loneMasterKeepsZone(
        _ windows: some Collection<WindowID>,
        params: StackParams,
        range: ClosedRange<Double>?
    ) -> Bool {
        windows.count == 1 && !params.fillWhenAlone && range != nil
    }

    /// The master zone's span: the stored ratio clamped into the
    /// range both zones can keep `minWindowSize` in (#44).
    static func masterSpan(
        available: CGFloat,
        ratio: Double,
        in range: ClosedRange<Double>
    ) -> CGFloat {
        available
            * CGFloat(
                min(max(ratio, range.lowerBound), range.upperBound)
            )
    }

    /// Master and stack regions for split of usable area (#222);
    /// public for the schematic's lone frame (#1389).
    public static func regions(
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

    /// Distributes windows along region axis weighted by `stackWeights`
    /// (#222, #67, `OverlapStack`).
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

    /// Cascades trailing windows when zone exceeds capacity.
    private func overflowZone(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        vertical: Bool,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let ids = Array(windows)
        guard
            let overflow = OverlapStack.overflowFrames(
                count: ids.count,
                in: region,
                vertical: vertical,
                minSize: context.minWindowSize,
                gap: vertical
                    ? context.gaps.inner.vertical
                    : context.gaps.inner.horizontal
            )
        else {
            return OverlapStack.frames(
                for: windows,
                in: region,
                minSize: context.minWindowSize
            )
        }
        // Sticky windows keep fully-tiled slot (#414 v2).
        let ordered = OverlapStack.stickyExempt(
            ids,
            tiled: overflow.tiled,
            sticky: context.sticky
        )
        return Dictionary(
            uniqueKeysWithValues: zip(ordered, overflow.rects)
        )
    }
}
