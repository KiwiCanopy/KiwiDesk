import CoreGraphics

/// Emergency fallback shared by BSP, Stack, and Grid.
///
/// When a layout would shrink windows below `minWindowSize`,
/// downsizing halts: windows keep the minimum size and cascade
/// with a fixed vertical offset so every title bar stays
/// visible and clickable.
public enum OverlapStack {
    /// Vertical cascade offset keeping title bars reachable.
    public static let offset: CGFloat = 40

    /// Cascades `windows` inside `region`.
    public static func frames(
        for windows: some Collection<WindowID>,
        in region: CGRect,
        minSize: CGFloat
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        let size = CGSize(
            width: max(region.width, minSize),
            height: max(region.height, minSize)
        )
        for (index, window) in windows.enumerated() {
            result[window] = CGRect(
                x: region.minX,
                y: region.minY + CGFloat(index) * offset,
                width: size.width,
                height: size.height
            )
        }
        return result
    }

    /// Partial-overflow layout along one axis: keep the longest
    /// fitting prefix of `count` items fully tiled at ≥ `minSize`
    /// each, and cascade only the remainder at a fixed title-bar
    /// `offset` so the buried ones stay reachable — the
    /// `cascade_overflow` rule. Returns one rect per item (index
    /// order), spanning the full cross-axis of `region`, or nil
    /// when not even one item fits above the cascade (the caller
    /// then cascades the whole region). `vertical` = items stack
    /// along Y (columns of a track / a stack column); false =
    /// along X (rows / side-by-side tracks). The single
    /// authority behind the stack column overflow and both track
    /// axes (#128), so the "tile the fitting, cascade the rest"
    /// geometry cannot drift between them.
    public static func overflowFrames(
        count: Int,
        in region: CGRect,
        vertical: Bool,
        minSize: CGFloat,
        gap: CGFloat
    ) -> [CGRect]? {
        guard count > 0 else { return [] }
        let primary = vertical ? region.height : region.width
        for tiled in stride(from: count - 1, through: 1, by: -1) {
            let buried = CGFloat(count - tiled - 1)
            let cascadeExtent = minSize + offset * buried
            let tileExtent =
                (primary - cascadeExtent - gap * CGFloat(tiled))
                / CGFloat(tiled)
            guard tileExtent >= minSize else { continue }
            var rects: [CGRect] = []
            rects.reserveCapacity(count)
            var pos = vertical ? region.minY : region.minX
            for _ in 0..<tiled {
                rects.append(
                    rect(
                        along: pos,
                        extent: tileExtent,
                        region: region,
                        vertical: vertical
                    )
                )
                pos += tileExtent + gap
            }
            for index in 0..<(count - tiled) {
                rects.append(
                    rect(
                        along: pos + CGFloat(index) * offset,
                        extent: minSize,
                        region: region,
                        vertical: vertical
                    )
                )
            }
            return rects
        }
        return nil
    }

    /// A rect occupying `[along, along+extent)` on the primary
    /// axis and the full cross-axis of `region`.
    private static func rect(
        along: CGFloat,
        extent: CGFloat,
        region: CGRect,
        vertical: Bool
    ) -> CGRect {
        vertical
            ? CGRect(
                x: region.minX,
                y: along,
                width: region.width,
                height: extent
            )
            : CGRect(
                x: along,
                y: region.minY,
                width: extent,
                height: region.height
            )
    }
}
