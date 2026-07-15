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
    ///
    /// `fitToRegion` shrinks each window's height (floored at
    /// `minSize`) so the whole cascade tries to end at the
    /// region's bottom edge. The quit grid's cross-row guard
    /// (#197): its piles keep whatever z-order remains after
    /// exit, so a pile spilling into the cell row below would
    /// bury unrelated title bars there. Live piles keep the
    /// full-region size — their z-order is actively managed
    /// (`KiwiCore+ZOrder`), so the spill is harmless and the
    /// bigger windows are worth it.
    public static func frames(
        for windows: some Collection<WindowID>,
        in region: CGRect,
        minSize: CGFloat,
        fitToRegion: Bool = false
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        let cascade =
            CGFloat(max(windows.count - 1, 0)) * offset
        let fullHeight = max(region.height, minSize)
        let size = CGSize(
            width: max(region.width, minSize),
            height: fitToRegion
                ? max(fullHeight - cascade, minSize)
                : fullHeight
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
    /// each, and pile the remainder as a **vertical** title-bar
    /// cascade so the buried ones stay reachable — the
    /// `cascade_overflow` rule. Returns one rect per item (index
    /// order), or nil when not even one item fits above the pile
    /// (the caller then cascades the whole region).
    ///
    /// `vertical` = the *tiling* axis: items tile along Y
    /// (columns of a track / a stack column) when true, along X
    /// (rows / side-by-side tracks) when false. The buried pile
    /// is **always** offset downward (Y), matching the shared
    /// `frames(_:in:minSize:)` cascade and every other layout's
    /// title-bar-reveal convention — a horizontal offset would
    /// reveal side slivers, not title bars. So when tiling is
    /// vertical the pile extends along the primary axis (and
    /// consumes `minSize + offset*buried` of it, the stack
    /// column geometry unchanged); when tiling is horizontal the
    /// pile extends down the cross axis and only reserves a
    /// `minSize` strip of the primary. The single authority
    /// behind the stack column overflow and both track axes
    /// (#128), so the geometry cannot drift between them.
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
            // The pile is vertical: along a vertical tiling axis
            // it eats `minSize + offset*buried` of the primary;
            // along a horizontal one it only needs a `minSize`
            // primary strip (its offset spends the cross axis).
            let cascadePrimary =
                vertical ? minSize + offset * buried : minSize
            let tileExtent =
                (primary - cascadePrimary - gap * CGFloat(tiled))
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
            // Buried items: a vertical title-bar cascade anchored
            // at the trailing edge of the tiled block.
            for index in 0..<(count - tiled) {
                let step = CGFloat(index) * offset
                rects.append(
                    vertical
                        ? CGRect(
                            x: region.minX,
                            y: pos + step,
                            width: region.width,
                            height: minSize
                        )
                        : CGRect(
                            x: pos,
                            y: region.minY + step,
                            width: region.maxX - pos,
                            height: minSize
                        )
                )
            }
            return rects
        }
        return nil
    }

    /// A tiled rect occupying `[along, along+extent)` on the
    /// primary axis and the full cross-axis of `region`.
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
