import CoreGraphics

/// Binary space partitioning layout over flat window array
/// (dwindle). Two per-space ratio scalars, not per-node ratios —
/// those need stable split identity, i.e. a tree, which the flat
/// array forbids (#56).
public struct BspLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        place(
            windows[...],
            in: context.usable,
            depth: 0,
            context: context,
            into: &result
        )
        return result
    }

    private func place(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        depth: Int,
        context: LayoutContext,
        into result: inout [WindowID: CGRect]
    ) {
        guard let first = windows.first else { return }
        guard windows.count > 1 else {
            result[first] = region
            return
        }

        let sideBySide: Bool
        switch context.bsp.strategy {
        case .longestSide:
            // Split the longer side to stay square-ish.
            sideBySide = region.width >= region.height
        case .alternating:
            sideBySide = depth.isMultiple(of: 2)
        }

        let firstRegion: CGRect
        let restRegion: CGRect

        if sideBySide {
            let gap = context.gaps.inner.horizontal
            let available = region.width - gap
            // Clamp the shared ratio into this region's own
            // effective range (#383): a value too extreme for the
            // region pins the neighbor to min_window_size instead
            // of collapsing the subtree into an OverlapStack. The
            // pile stays reserved for a region genuinely too
            // narrow for two min-size windows (range nil), the
            // honest last resort — matching the stack (#44).
            guard
                let range = SplitDomain.effectiveRatioRange(
                    available: Double(available),
                    minSize: Double(context.minWindowSize)
                )
            else {
                overlap(windows, in: region, context, &result)
                return
            }
            let ratio = CGFloat(
                min(
                    max(context.bsp.splitRatioH, range.lowerBound),
                    range.upperBound
                )
            )
            let firstWidth = available * ratio
            let restWidth = available - firstWidth
            firstRegion = CGRect(
                x: region.minX,
                y: region.minY,
                width: firstWidth,
                height: region.height
            )
            restRegion = CGRect(
                x: region.minX + firstWidth + gap,
                y: region.minY,
                width: restWidth,
                height: region.height
            )
        } else {
            let gap = context.gaps.inner.vertical
            let available = region.height - gap
            // Same per-region clamp on the stacked axis (#383).
            guard
                let range = SplitDomain.effectiveRatioRange(
                    available: Double(available),
                    minSize: Double(context.minWindowSize)
                )
            else {
                overlap(windows, in: region, context, &result)
                return
            }
            let ratio = CGFloat(
                min(
                    max(context.bsp.splitRatioV, range.lowerBound),
                    range.upperBound
                )
            )
            let firstHeight = available * ratio
            let restHeight = available - firstHeight
            firstRegion = CGRect(
                x: region.minX,
                y: region.minY,
                width: region.width,
                height: firstHeight
            )
            restRegion = CGRect(
                x: region.minX,
                y: region.minY + firstHeight + gap,
                width: region.width,
                height: restHeight
            )
        }

        result[first] = firstRegion
        place(
            windows.dropFirst(),
            in: restRegion,
            depth: depth + 1,
            context: context,
            into: &result
        )
    }

    private func overlap(
        _ windows: ArraySlice<WindowID>,
        in region: CGRect,
        _ context: LayoutContext,
        _ result: inout [WindowID: CGRect]
    ) {
        result.merge(
            OverlapStack.frames(
                for: windows,
                in: region,
                minSize: context.minWindowSize
            )
        ) { _, new in new }
    }
}
