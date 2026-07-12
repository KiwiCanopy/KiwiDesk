import CoreGraphics

/// Track layout over the flat array (#128).
///
/// Every window sits in exactly one track: break markers
/// (`Space.trackBreaks`) partition the tiled window list into
/// consecutive slices — vertical tracks are columns side by
/// side, horizontal tracks are rows. Track sizes come from
/// per-head weights (`Space.trackWeights`), window shares
/// within a track from the per-window `stackWeights` (#67,
/// verbatim). All session state; the partition is one level of
/// indexed slicing, never a tree (see 03_Layout).
///
/// This dissolves BSP's shared-ratio limitation: `resize`
/// across the axis grows MY track, along it grows MY share —
/// every resize has one true target.
public struct TrackLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        guard !windows.isEmpty else { return [:] }
        let params = context.track
        let counts = Self.counts(
            of: windows,
            breaks: context.trackBreaks,
            cap: params.trackCap
        )
        let weights = Self.ranges(of: counts).map {
            Self.weight(
                ofTrack: $0,
                tiled: windows,
                weights: context.trackWeights
            )
        }
        let vertical = params.axis == .vertical
        let gap =
            vertical
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let span =
            (vertical ? usable.width : usable.height)
            - gap * CGFloat(counts.count - 1)
        let total = weights.reduce(0, +)
        // The min-size cap shares the stack's authority (#44/
        // #67): when the smallest track would drop below
        // min_window_size, the tracks overflow (below).
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            height: Double(span),
            minSize: Double(context.minWindowSize)
        )
        // One region per track: proportional when everything
        // fits; otherwise cascade-overflow tiles the fitting
        // prefix and cascades the rest (the axis-general stack
        // rule, hard-coded — #180 dropped the knob). A
        // fully-degenerate span still cascades the whole space
        // (physics fallback, not a setting).
        let regions: [CGRect]
        if span > 0, total <= limit {
            regions = proportionalRegions(
                counts: counts,
                weights: weights,
                total: total,
                span: span,
                gap: gap,
                vertical: vertical,
                usable: usable
            )
        } else if let over = OverlapStack.overflowFrames(
            count: counts.count,
            in: usable,
            vertical: !vertical,
            minSize: context.minWindowSize,
            gap: gap
        ) {
            regions = over
        } else {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }

        var result: [WindowID: CGRect] = [:]
        for (track, range) in Self.ranges(of: counts).enumerated() {
            result.merge(
                trackFrames(
                    windows[range],
                    in: regions[track],
                    vertical: vertical,
                    context: context
                )
            ) { _, new in new }
        }
        return result
    }

    /// One region per track sized to its weight share of
    /// `span`, laid consecutively along the axis (columns when
    /// vertical, rows otherwise) with `gap` between.
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

    /// Distributes one track's windows along the axis, sized
    /// proportionally to their `stackWeights` (#67; absent =
    /// 1.0). Vertical tracks stack their windows top to
    /// bottom, horizontal tracks lay them side by side. When
    /// the smallest share stops fitting `minWindowSize`, the
    /// track cascade-overflows — the same axis-general rule as
    /// the cross-axis tracks (hard-coded, #180).
    private func trackFrames(
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
        let available =
            (vertical ? region.height : region.width)
            - gap * (count - 1)
        let weights = windows.map {
            max(context.stackWeights[$0] ?? 1, Self.weightFloor)
        }
        let total = weights.reduce(0, +)
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            height: Double(available),
            minSize: Double(context.minWindowSize)
        )
        guard available > 0, total <= limit else {
            let ids = Array(windows)
            if let rects = OverlapStack.overflowFrames(
                count: ids.count,
                in: region,
                vertical: vertical,
                minSize: context.minWindowSize,
                gap: gap
            ) {
                return Dictionary(
                    uniqueKeysWithValues: zip(ids, rects)
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
