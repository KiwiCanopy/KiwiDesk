import CoreGraphics

/// Binary space partitioning over a flat array (dwindle style):
/// the first window claims the split ratio of the region, the
/// rest recurse into the remainder. Side-by-side splits use
/// `splitRatioH`, stacked splits `splitRatioV` (#56) — two
/// per-space scalars, not per-node ratios (those need stable
/// split identity, i.e. a tree, which the flat array forbids).
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
            let ratio = CGFloat(context.bsp.splitRatioH)
            let gap = context.gaps.inner.horizontal
            let available = region.width - gap
            let firstWidth = available * ratio
            let restWidth = available - firstWidth
            if min(firstWidth, restWidth)
                < context.minWindowSize
            {
                overlap(windows, in: region, context, &result)
                return
            }
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
            let ratio = CGFloat(context.bsp.splitRatioV)
            let gap = context.gaps.inner.vertical
            let available = region.height - gap
            let firstHeight = available * ratio
            let restHeight = available - firstHeight
            if min(firstHeight, restHeight)
                < context.minWindowSize
            {
                overlap(windows, in: region, context, &result)
                return
            }
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
