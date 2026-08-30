import CoreGraphics

/// Quit teardown window layout styles (#197).
public enum QuitLayoutStyle: String, Codable, Sendable,
    CaseIterable
{
    case grid
}

/// Round-robin cascading grid quit layout math (#197, #281).
public enum QuitGridLayout {
    /// Default stack depth per cell before grid dimension expands (5, #281).
    public static let defaultTargetDepth = 5
    /// Accepted grid target depth range (1...20).
    public static let targetDepthRange = 1...20
    /// Teardown dimension ceiling (4x4 = 16 cells max per display).
    public static let maxDimension = 4

    /// Calculates grid dimension for `count` windows with `targetDepth` depth.
    public static func dimension(
        for count: Int,
        targetDepth: Int
    ) -> Int {
        let depth = max(targetDepth, 1)
        let needed = (Double(count) / Double(depth))
            .squareRoot()
            .rounded(.up)
        return min(max(Int(needed), 2), maxDimension)
    }

    /// Partitions windows into round-robin cell buckets.
    private static func buckets(
        for windows: [WindowID],
        targetDepth: Int
    ) -> [[WindowID]] {
        let dim = dimension(
            for: windows.count,
            targetDepth: targetDepth
        )
        var buckets = Array(
            repeating: [WindowID](),
            count: dim * dim
        )
        for (index, window) in windows.enumerated() {
            buckets[index % (dim * dim)].append(window)
        }
        return buckets
    }

    /// Computes target rects for windows arranged in round-robin cascading
    /// cells.
    public static func frames(
        for windows: [WindowID],
        in axFrame: CGRect,
        minSize: CGFloat,
        targetDepth: Int
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }
        let dim = dimension(
            for: windows.count,
            targetDepth: targetDepth
        )
        let width = axFrame.width / CGFloat(dim)
        let height = axFrame.height / CGFloat(dim)
        var result: [WindowID: CGRect] = [:]
        for (cell, bucket) in buckets(
            for: windows,
            targetDepth: targetDepth
        ).enumerated()
        where !bucket.isEmpty {
            let region = CGRect(
                x: axFrame.minX
                    + CGFloat(cell % dim) * width,
                y: axFrame.minY
                    + CGFloat(cell / dim) * height,
                width: width,
                height: height
            )
            result.merge(
                OverlapStack.frames(
                    for: bucket,
                    in: region,
                    minSize: minSize,
                    fitToRegion: true
                ).mapValues {
                    pinned($0, in: axFrame, minSize: minSize)
                }
            ) { current, _ in current }
        }
        return result
    }

    /// Deterministic raise circle order across quit grid cells (#688).
    public static func raiseOrder(
        for windows: [WindowID],
        targetDepth: Int
    ) -> [WindowID] {
        guard !windows.isEmpty else { return [] }
        return buckets(
            for: windows,
            targetDepth: targetDepth
        ).flatMap { $0 }
    }

    /// Pins frame origin so at least `minSize` stays inside visible `axFrame`.
    private static func pinned(
        _ frame: CGRect,
        in axFrame: CGRect,
        minSize: CGFloat
    ) -> CGRect {
        var frame = frame
        frame.origin.x = max(
            axFrame.minX,
            min(frame.origin.x, axFrame.maxX - minSize)
        )
        frame.origin.y = max(
            axFrame.minY,
            min(frame.origin.y, axFrame.maxY - minSize)
        )
        return frame
    }
}
