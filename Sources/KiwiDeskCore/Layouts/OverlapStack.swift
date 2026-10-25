import CoreGraphics

/// Emergency overflow fallback cascading windows with title bars visible.
public enum OverlapStack {
    /// Vertical cascade offset keeping title bars reachable.
    public static let offset: CGFloat = 40

    /// Cascades `windows` inside `region` (`KiwiCore+ZOrder`, #197).
    public static func frames(
        for windows: some Collection<WindowID>,
        in region: CGRect,
        minSize: MinSize,
        fitToRegion: Bool = false
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        let cascade =
            CGFloat(max(windows.count - 1, 0)) * offset
        let fullHeight = max(region.height, minSize.height)
        let size = CGSize(
            width: max(region.width, minSize.width),
            height: fitToRegion
                ? max(fullHeight - cascade, minSize.height)
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

    /// Computes partial-overflow frames for tiled and cascaded
    /// slots (#128). The buried pile is
    /// ALWAYS offset downward — a horizontal offset would reveal
    /// side slivers, not title bars — and this is the single
    /// authority behind the stack column overflow and both track
    /// axes, so the geometry cannot drift between them. A tile
    /// keeps the floor along `vertical`'s axis; a buried slot is
    /// the height floor tall either way.
    public static func overflowFrames(
        count: Int,
        in region: CGRect,
        vertical: Bool,
        minSize floor: MinSize,
        gap: CGFloat
    ) -> (rects: [CGRect], tiled: Int)? {
        guard count > 0 else { return ([], 0) }
        let minSize = floor.along(horizontal: !vertical)
        let primary = vertical ? region.height : region.width
        for tiled in stride(from: count - 1, through: 1, by: -1) {
            let buried = CGFloat(count - tiled - 1)
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
            // Buried items cascade at trailing edge.
            for index in 0..<(count - tiled) {
                let step = CGFloat(index) * offset
                rects.append(
                    vertical
                        ? CGRect(
                            x: region.minX,
                            y: pos + step,
                            width: region.width,
                            height: floor.height
                        )
                        : CGRect(
                            x: pos,
                            y: region.minY + step,
                            width: region.maxX - pos,
                            height: floor.height
                        )
                )
            }
            return (rects, tiled)
        }
        return nil
    }

    /// Tiled rect along primary axis of region.
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
