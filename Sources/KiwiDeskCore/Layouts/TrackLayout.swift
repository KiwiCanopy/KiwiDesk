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
        let vertical = params.axis == .vertical
        let gap =
            vertical
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        // The overflow track (#192): the surplus beyond the normal
        // capacity folds into ONE far-edge track. Normal capacity
        // is the fixed `track.set_limit` (auto off) or unlimited
        // (auto on); the overflow track is the EXTRA column past
        // it, so a limit of N shows up to N normal tracks + 1
        // overflow. Geometry always caps the total: if capacity+1
        // columns can't hold min size, the fit-count reduces (the
        // limit is display-agnostic; the display decides at render
        // time), never grows past it.
        // The render cap folds the surplus past the normal
        // capacity (`params.normalCap`: fixed `count`, or `.max`
        // when auto tracks caps by geometry alone) OR the
        // geometric fit into one far-edge overflow track. The
        // last slot is the overflow track whenever capacity is
        // exceeded — even when it holds a single window (the
        // N+1th track past a fixed limit), so no actual merge is
        // needed. `foldedPartition` is the one copy of this
        // assembly, shared with the swap guard and the heal.
        let (counts, _, overflowTrack) = Self.foldedPartition(
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
        // The min-size cap shares the stack's authority (#44/#67):
        // when even the merged tracks can't hold min_window_size
        // (a degenerate span), the whole space cascades —
        // physics, not a knob. A heavily-weighted track no
        // longer reaches this check through the session stores:
        // write-time clamps (#933) refuse one at press time and
        // the retile-time heal (#944) — which reasons over this
        // check's own folded partition — shaves one a
        // membership change left behind. So tripping it here
        // means the span itself cannot hold the members, a
        // transient no heal has seen yet, or a traveler's visit
        // (the heal deliberately reads LOCAL members; its doc
        // owns why).
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
            // Normal tracks always tile-then-pile; only the
            // far-edge overflow track honors `overflow_style`
            // (#192).
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
    /// track overflows per the caller's `overflowStyle` (#192):
    /// `cascade_overflow` tiles the fitting prefix and piles the
    /// rest; `cascade_all` piles every window from the top.
    /// Normal tracks are always called with `cascade_overflow`;
    /// only the far-edge overflow track honors the configured
    /// style.
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
