import CoreGraphics

/// Quit teardown window layout styles (#197).
public enum QuitLayoutStyle: String, Codable, Sendable,
    CaseIterable
{
    case grid
}

/// The quit grid (#197, #281, #1709): tiles first, then
/// round-robin cascading piles, laid with no gaps. `shape` is
/// the one choice of (columns, rows); the partition deals into
/// it and `GridLayout.cellFrames` draws the cells, the last tile
/// filling its short line as the Grid layout's
/// `fill_empty_cells` does. Past the tiles each cell takes an
/// `OverlapStack` pile.
public enum QuitGridLayout {
    /// Default stack depth per cell before grid dimension expands (5, #281).
    public static let defaultTargetDepth = 5
    /// Accepted grid target depth range (1...20).
    public static let targetDepthRange = 1...20
    /// Teardown dimension ceiling (4 per axis), a safety boundary
    /// and deliberately not configurable. The tile cap, the
    /// ladder and its thresholds are restated as prose in
    /// `docs/lua-reference.md` and `BehaviorSection`'s
    /// `behavior.quit.target_depth.help` — changing any of them
    /// updates those sites too.
    public static let maxDimension = 4
    /// The stack grids, smallest first, as (splits along the
    /// region's long axis, splits across it): 3×2 → 4×2 → 4×3 →
    /// 4×4 on a landscape region, mirrored on a portrait one.
    static let ladder: [(along: Int, across: Int)] = [
        (3, 2), (4, 2), (4, 3), (maxDimension, maxDimension),
    ]
    /// The most windows laid as tiles before any pile forms: the
    /// first rung's cells.
    static let tileCap = ladder[0].along * ladder[0].across

    /// The grid a gather draws for `count` windows in `region` —
    /// the ONE choice of (columns, rows); the partition only
    /// deals into it. Up to `tileCap`, the tile shape
    /// (`tileSplits`); past it, the smallest ladder rung whose
    /// cells hold `count` in piles `targetDepth` deep — at depth
    /// 5, 7–30 windows take 3×2, 31–40 4×2, 41–60 4×3 and more
    /// 4×4, whose piles just deepen.
    public static func shape(
        tiles count: Int,
        in region: CGRect,
        targetDepth: Int
    ) -> (columns: Int, rows: Int) {
        let depth = max(targetDepth, 1)
        let splits =
            count <= tileCap
            ? tileSplits(for: count, in: region)
            : ladder.first { $0.along * $0.across * depth >= count }
                ?? ladder[ladder.count - 1]
        return isPortrait(region)
            ? (splits.across, splits.along)
            : (splits.along, splits.across)
    }

    /// The tile shape for `count` windows: the split whose cells
    /// come nearest square — least |ln(cell width ÷ height)| —
    /// among those leaving no line empty and neither axis past
    /// `maxDimension`, a tie taking fewer splits across the
    /// short axis. On 16:9 that is 1, 2 and 3 in a row, 4 as
    /// 2×2, 5 and 6 as 3×2; 16:10 lays 3 as 2 + 1 and 32:9 lays
    /// 4 in a row.
    static func tileSplits(
        for count: Int,
        in region: CGRect
    ) -> (along: Int, across: Int) {
        let long = Double(max(region.width, region.height))
        let short = Double(min(region.width, region.height))
        var best: (along: Int, across: Int)?
        var bestCost = Double.infinity
        for across in 1...maxDimension {
            let along = ceilDiv(count, across)
            guard along > 0, along <= maxDimension,
                ceilDiv(count, along) == across
            else { continue }
            let ratio =
                (long / Double(along)) / (short / Double(across))
            let cost = abs(log(ratio))
            if best == nil || cost < bestCost {
                best = (along, across)
                bestCost = cost
            }
        }
        return best ?? (1, 1)
    }

    private static func ceilDiv(_ a: Int, _ b: Int) -> Int {
        (a + b - 1) / b
    }

    /// The shared partition behind `frames` and `raiseOrder`:
    /// both MUST agree, or the raise circle stacks a different
    /// pile than the one placed (#688). A tile per window while
    /// they fit, the last filling its row; round-robin piles over
    /// every cell once they do not.
    private static func partition(
        for windows: [WindowID],
        in region: CGRect,
        targetDepth: Int
    ) -> [(pile: [WindowID], cell: CGRect)] {
        let (columns, rows) = shape(
            tiles: windows.count,
            in: region,
            targetDepth: targetDepth
        )
        let capacity = columns * rows
        let stacks = windows.count > capacity
        let cells = GridLayout.cellFrames(
            count: stacks ? capacity : windows.count,
            columns: columns,
            rows: rows,
            in: region,
            gapH: 0,
            gapV: 0,
            rowMajor: !isPortrait(region),  // portrait: column-first
            fillLast: !stacks
        )
        var piles = Array(repeating: [WindowID](), count: cells.count)
        for (index, window) in windows.enumerated() {
            piles[index % cells.count].append(window)
        }
        return Array(zip(piles, cells))
    }

    /// Computes target rects for windows arranged in tiles, then
    /// round-robin cascading cells.
    public static func frames(
        for windows: [WindowID],
        in axFrame: CGRect,
        minSize: CGFloat,
        targetDepth: Int
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }
        var result: [WindowID: CGRect] = [:]
        for (pile, cell) in partition(
            for: windows,
            in: axFrame,
            targetDepth: targetDepth
        ) {
            result.merge(
                OverlapStack.frames(
                    for: pile,
                    in: cell,
                    minSize: minSize,
                    fitToRegion: true
                ).mapValues {
                    pinned($0, in: axFrame, minSize: minSize)
                }
            ) { current, _ in current }
        }
        return result
    }

    /// Deterministic raise circle order across quit-grid cells.
    /// The order is the whole promise — the resulting stacking is
    /// the caller's: `restackForTeardown` drops one member (the
    /// unbeatable key window) and is wall-clock bounded, so read
    /// the guarantees as properties of the circle, not of every
    /// quit (#688). `axFrame` is the one `frames` lays in, so the
    /// one partition reads identical inputs; it does not change
    /// the order, which is cell by cell in the fill order.
    public static func raiseOrder(
        for windows: [WindowID],
        in axFrame: CGRect,
        targetDepth: Int
    ) -> [WindowID] {
        guard !windows.isEmpty else { return [] }
        return partition(
            for: windows,
            in: axFrame,
            targetDepth: targetDepth
        ).flatMap(\.pile)
    }

    /// A region taller than wide takes the mirrored grid.
    static func isPortrait(_ region: CGRect) -> Bool {
        region.height > region.width
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
