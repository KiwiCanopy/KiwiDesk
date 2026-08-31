import CoreGraphics

/// Track layout partitioning flat window array into columns/rows (#128, #67).
public struct TrackLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        guard !windows.isEmpty else { return [:] }
        let params = context.track
        let vertical = params.axis == .vertical
        let gap =
            vertical
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let (counts, _, _, overflowTrack) = Self.foldedPartition(
            of: windows,
            breaks: context.trackBreaks,
            normalCap: params.normalCap,
            geoCap: Self.geometricCap(for: context)
        )
        let weights = Self.ranges(of: counts).map {
            Self.weight(
                ofTrack: $0,
                tiled: windows,
                weights: context.trackWeights
            )
        }
        let span =
            (vertical ? usable.width : usable.height)
            - gap * CGFloat(counts.count - 1)
        let total = weights.reduce(0, +)
        // Degenerate span cascades if tracks cannot satisfy min_window_size
        // (#44, #67, #933, #944).
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            span: Double(span),
            minSize: Double(context.minWindowSize)
        )
        guard span > 0, total <= limit else {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }
        let regions = proportionalRegions(
            counts: counts,
            weights: weights,
            total: total,
            span: span,
            gap: gap,
            vertical: vertical,
            usable: usable
        )
        var result: [WindowID: CGRect] = [:]
        for (track, range) in Self.ranges(of: counts).enumerated() {
            // Far-edge overflow track honors overflow_style (#192).
            let style: StackParams.OverflowStyle =
                track == overflowTrack
                ? params.overflowStyle : .cascadeOverflow
            result.merge(
                trackFrames(
                    windows[range],
                    in: regions[track],
                    vertical: vertical,
                    overflowStyle: style,
                    context: context
                )
            ) { _, new in new }
        }
        return result
    }

    /// Computes proportional track regions along axis.
    private func proportionalRegions(
        counts: [Int],
        weights: [Double],
        total: Double,
        span: CGFloat,
        gap: CGFloat,
        vertical: Bool,
        usable: CGRect
    ) -> [CGRect] {
        var regions: [CGRect] = []
        regions.reserveCapacity(counts.count)
        var origin = vertical ? usable.minX : usable.minY
        for track in counts.indices {
            let size = span * CGFloat(weights[track] / total)
            regions.append(
                vertical
                    ? CGRect(
                        x: origin,
                        y: usable.minY,
                        width: size,
                        height: usable.height
                    )
                    : CGRect(
                        x: usable.minX,
                        y: origin,
                        width: usable.width,
                        height: size
                    )
            )
            origin += size + gap
        }
        return regions
    }

    /// Distributes track windows proportionally by `stackWeights` (#67, #192).
    private func trackFrames(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        vertical: Bool,
        overflowStyle: StackParams.OverflowStyle,
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        let count = CGFloat(windows.count)
        guard count > 0 else { return [:] }
        let gap =
            vertical
            ? context.gaps.inner.vertical
            : context.gaps.inner.horizontal
        let available =
            (vertical ? region.height : region.width)
            - gap * (count - 1)
        let weights = windows.map {
            max(context.stackWeights[$0] ?? 1, Self.weightFloor)
        }
        let total = weights.reduce(0, +)
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            span: Double(available),
            minSize: Double(context.minWindowSize)
        )
        guard available > 0, total <= limit else {
            // cascade_all piles every window from the top; the
            // whole-region cascade is also the physics fallback
            // when not even the fitting prefix holds (#192).
            if overflowStyle == .cascadeAll {
                return OverlapStack.frames(
                    for: windows,
                    in: region,
                    minSize: context.minWindowSize
                )
            }
            let ids = Array(windows)
            if let overflow = OverlapStack.overflowFrames(
                count: ids.count,
                in: region,
                vertical: vertical,
                minSize: context.minWindowSize,
                gap: gap
            ) {
                // Sticky windows keep a fully-tiled slot
                // (#414 v2); non-sticky ones overflow instead.
                let ordered = OverlapStack.stickyExempt(
                    ids,
                    tiled: overflow.tiled,
                    sticky: context.sticky
                )
                return Dictionary(
                    uniqueKeysWithValues: zip(
                        ordered,
                        overflow.rects
                    )
                )
            }
            return OverlapStack.frames(
                for: windows,
                in: region,
                minSize: context.minWindowSize
            )
        }
        var result: [WindowID: CGRect] = [:]
        var position = vertical ? region.minY : region.minX
        for (offset, window) in windows.enumerated() {
            let share =
                available * CGFloat(weights[offset] / total)
            result[window] =
                vertical
                ? CGRect(
                    x: region.minX,
                    y: position,
                    width: region.width,
                    height: share
                )
                : CGRect(
                    x: position,
                    y: region.minY,
                    width: share,
                    height: region.height
                )
            position += share + gap
        }
        return result
    }
}
