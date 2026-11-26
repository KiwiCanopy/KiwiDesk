import CoreGraphics

/// Which split a BSP resize moves (#3672): the one resolver every
/// ratio door — the keyboard press, the mouse drag, the floor heal —
/// takes. Split k puts `windows[k]` on its first side (left or top)
/// and the rest on its second, so a window's trailing edge on an axis
/// is its own split where that split runs along the axis, and its
/// leading edge the nearest ancestor split on the axis.
extension BspLayout {
    /// The edge of the resized window a resize moves.
    public enum SplitEdge: Sendable {
        case leading, trailing
        /// A keyboard press: the trailing edge where the window's own
        /// split runs along the axis, else the leading one.
        case either
    }

    /// The split a resize moves, and how it answers the resize.
    public struct SplitOwner: Equatable, Sendable {
        /// The window whose split it is, `windows[depth]`.
        public let owner: WindowID
        public let depth: Int
        public let sideBySide: Bool
        /// +1 where the ratio rising grows the resized window (it is
        /// the split's first side), -1 where it sits in the rest.
        public let sign: Double
        /// The points the split divides: its region less the gap.
        public let available: Double
        /// The windows on the split's second side, in depth order.
        public let rest: [WindowID]
    }

    /// The split a resize of `window` along `horizontal`'s axis moves
    /// at `edge`; nil where that edge is the layout region's own, or
    /// `window` is not among `windows`.
    public static func splitOwner(
        of window: WindowID,
        horizontal: Bool,
        edge: SplitEdge,
        windows: [WindowID],
        in context: LayoutContext
    ) -> SplitOwner? {
        guard let depth = windows.firstIndex(of: window) else { return nil }
        let plan = plan(windows, in: context)
        let gap =
            horizontal
            ? context.gaps.inner.horizontal : context.gaps.inner.vertical
        func owner(at k: Int, sign: Double) -> SplitOwner {
            let region = plan.regions[k]
            return SplitOwner(
                owner: windows[k],
                depth: k,
                sideBySide: horizontal,
                sign: sign,
                available: Double(
                    (horizontal ? region.width : region.height) - gap
                ),
                rest: Array(windows[(k + 1)...])
            )
        }
        if edge != .leading, depth < plan.splits.count,
            plan.splits[depth] == horizontal
        {
            return owner(at: depth, sign: 1)
        }
        guard edge != .trailing else { return nil }
        let first = min(depth, plan.splits.count) - 1
        for k in stride(from: first, through: 0, by: -1)
        where plan.splits[k] == horizontal {
            return owner(at: k, sign: -1)
        }
        return nil
    }

    /// Every split made ahead of any chain, in depth order, each
    /// answering a resize of its owner's trailing edge.
    public static func splits(
        of windows: [WindowID],
        in context: LayoutContext
    ) -> [SplitOwner] {
        let made = plan(windows, in: context).splits
        return made.indices.compactMap {
            splitOwner(
                of: windows[$0],
                horizontal: made[$0],
                edge: .trailing,
                windows: windows,
                in: context
            )
        }
    }

    /// Whether any split ahead of a scrolled chain runs along the
    /// axis `horizontal` names, and whether any split is made at all.
    static func divides(
        _ windows: [WindowID],
        horizontal: Bool,
        in context: LayoutContext
    ) -> (axis: Bool, any: Bool) {
        let splits = plan(windows, in: context).splits
        return (splits.contains(horizontal), !splits.isEmpty)
    }

    /// The least length `split`'s rest takes along its axis, with the
    /// window that carries the largest floor in it: a same-axis split
    /// below adds its window's floor and the gap, a cross-axis one
    /// takes the larger of the two, and a scrolled chain its largest
    /// member floor.
    public static func restMinimum(
        of split: SplitOwner,
        windows: [WindowID],
        in context: LayoutContext,
        floor: (WindowID) -> Double
    ) -> (size: Double, carrier: WindowID?) {
        let splits = plan(windows, in: context).splits
        let gap = Double(
            split.sideBySide
                ? context.gaps.inner.horizontal : context.gaps.inner.vertical
        )
        let tail = windows[max(splits.count, split.depth + 1)...]
        var total = tail.map(floor).max() ?? 0
        if splits.count > split.depth + 1 {
            for j in stride(
                from: splits.count - 1,
                through: split.depth + 1,
                by: -1
            ) {
                let own = floor(windows[j])
                total =
                    splits[j] == split.sideBySide
                    ? own + gap + total : max(own, total)
            }
        }
        let carrier = split.rest.max { floor($0) < floor($1) }
        return (total, carrier)
    }
}
