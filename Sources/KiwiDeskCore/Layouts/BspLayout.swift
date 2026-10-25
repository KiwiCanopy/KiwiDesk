import CoreGraphics

/// Binary space partitioning layout over flat window array
/// (dwindle). Two per-space ratio scalars, not per-node ratios —
/// those need stable split identity, i.e. a tree, which the flat
/// array forbids (#56). Where a split no longer fits two windows
/// at `min_window_size`, the trailing chain scrolls instead
/// (`BspLayout+Run`, #2542).
public struct BspLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let plan = Self.plan(windows, in: context)
        var result = plan.fixed
        if let zone = plan.zone {
            result.merge(zone.frames(in: context)) { _, new in new }
        }
        return result
    }

    /// Whether the split at `depth` puts its two sides next to
    /// each other (a vertical line) rather than one above the
    /// other.
    static func sideBySide(
        _ region: CGRect,
        depth: Int,
        _ context: LayoutContext
    ) -> Bool {
        switch context.bsp.strategy {
        case .longestSide:
            // Split the longer side to stay square-ish.
            region.width >= region.height
        case .alternating:
            depth.isMultiple(of: 2)
        }
    }

    /// `region` divided at the shared ratio, clamped into the
    /// region's own range (#383) so neither side falls under
    /// `min_window_size` and the rest under `restFloor`; nil
    /// where the region cannot hold two windows at the minimum.
    static func divide(
        _ region: CGRect,
        sideBySide: Bool,
        restFloor: CGFloat = 0,
        _ context: LayoutContext
    ) -> (first: CGRect, rest: CGRect)? {
        let gap =
            sideBySide
            ? context.gaps.inner.horizontal : context.gaps.inner.vertical
        let available =
            (sideBySide ? region.width : region.height) - gap
        let floor = context.minWindowSize.along(horizontal: sideBySide)
        // A rest floor past what the first window leaves is held
        // to that much: the first window keeps the minimum.
        let restMin = max(floor, min(restFloor, available - floor))
        guard
            let range = SplitDomain.effectiveRatioRange(
                available: Double(available),
                minLow: Double(floor),
                minHigh: Double(restMin)
            )
        else { return nil }
        let stored =
            sideBySide ? context.bsp.splitRatioH : context.bsp.splitRatioV
        let ratio = CGFloat(
            min(max(stored, range.lowerBound), range.upperBound)
        )
        let lead = available * ratio
        if sideBySide {
            return (
                CGRect(
                    x: region.minX,
                    y: region.minY,
                    width: lead,
                    height: region.height
                ),
                CGRect(
                    x: region.minX + lead + gap,
                    y: region.minY,
                    width: available - lead,
                    height: region.height
                )
            )
        }
        return (
            CGRect(
                x: region.minX,
                y: region.minY,
                width: region.width,
                height: lead
            ),
            CGRect(
                x: region.minX,
                y: region.minY + lead + gap,
                width: region.width,
                height: available - lead
            )
        )
    }
}
