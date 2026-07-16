import CoreGraphics

/// Quit-time teardown placement (#197): how remaining managed
/// windows are arranged when KiwiDesk exits. Lua
/// `quit.set_layout` → JSON `quit.layout`.
///
/// The strategy seam: a future style (center, columns, …) adds
/// a case here plus its own pure target function in the
/// `QuitGridLayout` pattern — `WindowGather.targets` switches
/// over this enum. `grid` is the only accepted value today.
public enum QuitLayoutStyle: String, Codable, Sendable,
    CaseIterable
{
    case grid
}

/// The `grid` quit layout: a per-display round-robin grid with
/// an `overflow_all`-style cascade in **every** cell (the
/// normal grid layout piles only the last cell). Pure math
/// over one display's flat window list; the state walk lives
/// in `WindowGather` (Teardown).
public enum QuitGridLayout {
    /// Standard stack depth a cell targets before the grid
    /// grows a dimension (`quit.grid_target_depth`, #281). Not
    /// a hard maximum: past the 4×4 cap, cells keep cascading.
    public static let defaultTargetDepth = 5
    /// The accepted density range — one source for the
    /// `quit.set_grid_target_depth` command and the GUI
    /// stepper, so their bounds cannot drift.
    public static let targetDepthRange = 1...20
    /// Dimension cap: at most 4×4 = 16 cells per display. A
    /// teardown safety boundary (min window size, cascade
    /// reachability, no live manager after quit), not a visual
    /// preference — deliberately not configurable. The 2×2…4×4
    /// span and its 4T/9T growth thresholds are restated as
    /// prose in `BehaviorSection` (help + live summary),
    /// `docs/user-guide.md`, and `docs/lua-reference.md` —
    /// changing the cap or the formula means updating those
    /// four sites too.
    public static let maxDimension = 4

    /// Grid dimension for `count` windows:
    /// `clamp(ceil(sqrt(count / targetDepth)), 2, maxDimension)`.
    /// One formula, no branch list — at the standard target 5:
    /// ≤20 → 2×2, ≤45 → 3×3, above → 4×4 (capped).
    public static func dimension(
        for count: Int,
        targetDepth: Int
    ) -> Int {
        // Range enforcement lives at the command/GUI edges;
        // the pure math only guards the division.
        let depth = max(targetDepth, 1)
        let needed = (Double(count) / Double(depth))
            .squareRoot()
            .rounded(.up)
        return min(max(Int(needed), 2), maxDimension)
    }

    /// Round-robin cell buckets: window `i` lands in cell
    /// `i % cells` (row-major). The shared partition behind
    /// `frames` and `raiseOrder` — both MUST agree, or the
    /// raise circle stacks a different pile than the one
    /// placed.
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

    /// Round-robin targets for one display: window `i` lands
    /// in cell `i % cells` (row-major over `axFrame`), and
    /// each cell's pile cascades like `overflow_all`
    /// (`OverlapStack.frames`, fit to the cell) so no pile
    /// spills into the row below.
    ///
    /// Frames alone don't fix stacking — the quit path raises
    /// every window in `raiseOrder` after placing, which is
    /// what makes each pile's title bars visible.
    ///
    /// `axFrame` is the display's visible frame in AX
    /// (top-left-origin) coordinates; the returned rects are
    /// AX too.
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

    /// The deterministic raise circle for one display: cell
    /// by cell (row-major — quadrant 1, 2, 3, 4), each pile
    /// top slot first and deepest slot last. Raising in this
    /// order makes the final stacking independent of whatever
    /// z-order (and focus) existed at quit: within a pile
    /// every title bar stays visible, and a later row always
    /// sits above the row before it, so even a degenerate
    /// pile that spills downward cannot bury the next row's
    /// headers.
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

    /// Pins a cascaded frame's origin so at least `minSize`
    /// of the window stays inside `axFrame`. Deep piles in
    /// bottom-row cells (past 4×4 the cascade depth is
    /// unbounded) and minSize-floored cells on tiny displays
    /// would otherwise push title bars off-screen —
    /// unrecoverable once no manager is alive.
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
