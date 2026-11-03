import CoreGraphics

/// Track layout partitioning flat window array into columns/rows (#128, #67).
public struct TrackLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }
        guard let zones = Self.zones(for: windows, in: context) else {
            return OverlapStack.frames(
                for: windows,
                in: context.usable,
                minSize: context.minWindowSize
            )
        }
        var result: [WindowID: CGRect] = [:]
        for zone in zones {
            result.merge(zone.frames(in: context)) { _, new in new }
        }
        return result
    }

    /// One zone per drawn track, each scrolling its own overflow
    /// (#2235); nil where the tracks cannot keep the minimum size
    /// across the axis and every window piles (#44, #67, #933,
    /// #944).
    public static func zones(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [RunZone]? {
        let usable = context.usable
        guard !windows.isEmpty else { return [] }
        let vertical = context.track.axis == .vertical
        let gap =
            vertical
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let counts = renderPartition(of: windows, in: context).counts
        let weights = ranges(of: counts).map {
            weight(
                ofTrack: $0,
                tiled: windows,
                weights: context.trackWeights
            )
        }
        let span =
            (vertical ? usable.width : usable.height)
            - gap * CGFloat(counts.count - 1)
        let total = weights.reduce(0, +)
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            span: Double(span),
            minSize: Double(
                context.minWindowSize.along(horizontal: vertical)
            )
        )
        guard span > 0, total <= limit else { return nil }
        let regions = proportionalRegions(
            counts: counts,
            weights: weights,
            total: total,
            span: span,
            gap: gap,
            vertical: vertical,
            usable: usable
        )
        return ranges(of: counts).enumerated().map { track, range in
            RunZone(
                members: Array(windows[range]),
                region: regions[track],
                vertical: vertical
            )
        }
    }

    /// Computes proportional track regions along axis.
    private static func proportionalRegions(
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
}
