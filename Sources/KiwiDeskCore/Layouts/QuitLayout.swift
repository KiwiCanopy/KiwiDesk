import CoreGraphics

/// Quit-time teardown placement (#197): how remaining managed
/// windows are arranged when KiwiDesk exits. Lua
/// `quit.set_layout` → JSON `quit.layout`.
///
/// The strategy seam: a future style (center, columns, …) adds
/// a case here plus its own pure target function in the
/// `QuitGridLayout` pattern — `WindowGather.targets` switches
/// over this enum. `grid` is the only accepted value today.
public enum QuitLayoutStyle: String, Codable, Sendable {
    case grid
}

/// The `grid` quit layout: a per-display round-robin grid with
/// an `overflow_all`-style cascade in **every** cell (the
/// normal grid layout piles only the last cell). Pure math
/// over one display's flat window list; the state walk lives
/// in `WindowGather` (Teardown).
public enum QuitGridLayout {
    /// Stack depth a cell targets before the grid grows a
    /// dimension.
    public static let maxDepth = 10
    /// Dimension cap: at most 4×4 = 16 cells per display.
    public static let maxDimension = 4

    /// Grid dimension for `count` windows:
    /// `clamp(ceil(sqrt(count / maxDepth)), 2, maxDimension)`.
    /// One formula, no branch list — ≤40 → 2×2, ≤90 → 3×3,
    /// ≤160 → 4×4 (capped).
    public static func dimension(for count: Int) -> Int {
        let needed = (Double(count) / Double(maxDepth))
            .squareRoot()
            .rounded(.up)
        return min(max(Int(needed), 2), maxDimension)
    }

    /// Round-robin targets for one display: window `i` lands
    /// in cell `i % cells` (row-major over `axFrame`), and
    /// each cell's pile cascades like `overflow_all`
    /// (`OverlapStack.frames`) so every title bar stays
    /// reachable.
    ///
    /// `axFrame` is the display's visible frame in AX
    /// (top-left-origin) coordinates; the returned rects are
    /// AX too.
    public static func frames(
        for windows: [WindowID],
        in axFrame: CGRect,
        minSize: CGFloat
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }
        let dim = dimension(for: windows.count)
        let cells = dim * dim
        var buckets = Array(
            repeating: [WindowID](),
            count: cells
        )
        for (index, window) in windows.enumerated() {
            buckets[index % cells].append(window)
        }
        let width = axFrame.width / CGFloat(dim)
        let height = axFrame.height / CGFloat(dim)
        var result: [WindowID: CGRect] = [:]
        for (cell, bucket) in buckets.enumerated()
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
                    minSize: minSize
                )
            ) { current, _ in current }
        }
        return result
    }
}
