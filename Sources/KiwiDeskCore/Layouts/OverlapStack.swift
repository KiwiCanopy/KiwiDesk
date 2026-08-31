import CoreGraphics

/// Emergency overflow fallback cascading windows with title bars visible.
public enum OverlapStack {
    /// Vertical cascade offset keeping title bars reachable.
    public static let offset: CGFloat = 40

    /// Cascades `windows` inside `region` (`KiwiCore+ZOrder`, #197).
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

    /// Computes partial-overflow frames for tiled and cascaded slots
    /// (`stickyExempt`, #128, #414 v2).
    public static func overflowFrames(
        count: Int,
        in region: CGRect,
        vertical: Bool,
        minSize: CGFloat,
        gap: CGFloat
    ) -> (rects: [CGRect], tiled: Int)? {
        guard count > 0 else { return ([], 0) }
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
            return (rects, tiled)
        }
        return nil
    }

    /// Reorders windows to ensure sticky windows retain fully-tiled slots
    /// (#414 v2).
    public static func stickyExempt(
        _ ids: [WindowID],
        tiled: Int,
        sticky: Set<WindowID>
    ) -> [WindowID] {
        guard tiled > 0, tiled < ids.count, !sticky.isEmpty
        else { return ids }
        let piled = ids[tiled...].filter { sticky.contains($0) }
        guard !piled.isEmpty else { return ids }
        var prefix = Array(ids[..<tiled])
        var displaced: [WindowID] = []
        for index in stride(
            from: prefix.count - 1,
            through: 0,
            by: -1
        )
        where displaced.count < piled.count
            && !sticky.contains(prefix[index])
        {
            displaced.insert(prefix.remove(at: index), at: 0)
        }
        let promoted = piled.prefix(displaced.count)
        let rest = ids[tiled...].filter {
            !promoted.contains($0)
        }
        return prefix + promoted + displaced + rest
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
