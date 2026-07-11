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
            cap: params.count
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
        // min_window_size, the whole space cascades — two
        // min-size tracks that cannot coexist have no honest
        // tiled answer.
        let limit = StackLayout.maxColumnTotal(
            smallestWeight: weights.min() ?? 1,
            height: Double(span),
            minSize: Double(context.minWindowSize)
        )
        guard span > 0, total <= limit else {
            return OverlapStack.frames(
                for: windows,
                in: usable,
                minSize: context.minWindowSize
            )
        }

        var result: [WindowID: CGRect] = [:]
        var origin = vertical ? usable.minX : usable.minY
        for (track, range) in Self.ranges(of: counts).enumerated() {
            let size = span * CGFloat(weights[track] / total)
            let region =
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
            result.merge(
                trackFrames(
                    windows[range],
                    in: region,
                    vertical: vertical,
                    context: context
                )
            ) { _, new in new }
            origin += size + gap
        }
        return result
    }

    /// Distributes one track's windows along the axis, sized
    /// proportionally to their `stackWeights` (#67; absent =
    /// 1.0). Vertical tracks stack their windows top to
    /// bottom, horizontal tracks lay them side by side. When
    /// the smallest share stops fitting `minWindowSize`, the
    /// track cascades (the shared last-resort fallback).
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
